# == Schema Information
# Schema version: 20101111214254
#
# Table name: meets
#
#  id             :integer         not null, primary key
#  name           :string(255)
#  description    :text
#  time           :datetime
#  location       :string(255)
#  street_address :string(255)
#  city           :string(255)
#  state          :string(255)
#  zip            :string(255)
#  country        :string(255)
#  image_url      :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  lng            :decimal(15, 10)
#  lat            :decimal(15, 10)
#  lerror         :float
#

require 'geokit'
require 'kaya_base'

class Meet < ActiveRecord::Base
  attr_accessor :meet_mview, :hoster_mview
  attr_accessor :loaded_top_users, :loaded_top_chatters
  attr_accessor :meet_invitations
  attr_accessor :loaded_users, :loaded_topics, :new_users, :new_topics,
                :is_new_invitation, :is_first_encounter
# attr_accessible :name, :description, :meet_type,
#                 :time, :location, :street_address, :city, 
#                 :state, :zip, :country, :lng, :lat, :lerror,
#                 :image_url, :collision

  has_many :mposts, :dependent => :destroy, :inverse_of => :meet

  belongs_to :hoster, :class_name => "User", :inverse_of => :hosted_meets

  has_many :users, :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 0]
  has_many :deleted_users, :class_name => "User", :source => :user,
                   :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 1]
  has_many :pending_users, :class_name => "User", :source => :user,
                   :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 2]

  has_many :chatters, :dependent => :destroy, :inverse_of => :meet
  has_many :topics, :class_name => "Chatter",
                    :conditions => ['chatters.topic_id IS NULL']
  has_many :photos, :class_name => "Chatter",
                    :conditions => ['chatters.photo_content_type IS NOT NULL']
# has_many :latest_chatters, :class_name => "Chatter", :limit => 3,
#                   :conditions => ['chatters.content IS NOT NULL && chatters.content != ?', ""]

  has_many :invitations, :dependent => :destroy, :inverse_of => :meet
  has_many :mviews, :dependent => :destroy, :inverse_of => :meet

  #accepts_nested_attributes_for :chatters, :reject_if => :all_blank, :allow_destroy => true

  validates :name,  :presence => true, :length   => { :maximum => 250 }
  validates :time,  :presence => { :message => "date time missing or unrecognized format" }
  validates :lng,   :numericality => { :greater_than_or_equal_to => BigDecimal("-180.0"),
                                       :less_than_or_equal_to    => BigDecimal(" 180.0"),
                                       :allow_nil => false }
  validates :lat,   :numericality => { :greater_than_or_equal_to => BigDecimal("-90.0"),
                                       :less_than_or_equal_to    => BigDecimal(" 90.0"),
                                       :allow_nil => false }

  default_scope :order => 'meets.time DESC'

  serialize :cached_info

  # Following functions are created by hong.zhao
  # They are required by backend processer.
  # Eearliest and oldest occure time of the meet. Use the :time instead but have
  # to make sure it is converted into utc time. It can also be extracted from
  # mpost dynamically.
  def occured_earliest
    return time? ? time.getutc : nil
  end
  def occured_latest
    return time? ? time.getutc : nil
  end

  def extract_information
    # Extract meeting time (average time)
    unique_users = Set.new
    notes = Hash.new
    self.collision = false if collision.nil?
    if !collision
      # Do not check collision on deleted mposts and non-peer mode mposts
      self.collision = mposts.any? {|mpost| !mpost.deleted? && mpost.is_peer_mode? && mpost.collision?}
    end
    mposts.each {|mpost|
      if (collision && !mpost.deleted?)
        mpost.delete; mpost.save
      end
      next unless mpost.active?
      if mpost.note.present? # Only count non-empty note
        if notes[mpost.note]
          notes[mpost.note] += 1
        else
          notes[mpost.note] = 1
        end
      end
      unique_users << mpost.user_id
      if host_id.blank? # only process host_id once, because they are all same
        self.host_id = mpost.host_id.split.last if mpost.host_id.present?
      end
    }
    #For host and warm meets, there are still copies in memory cluster. Still need
#   if collision
#     #some information for them to proceed correctly.
#     #return self # won't bother processing more information
#   end

    # Get non-host mode mposts, extract time and location from them if possible
    peer_mposts = mposts.select {|mpost| mpost.active? && mpost.is_peer_mode?}
    peer_mposts = mposts.select {|mpost| mpost.is_peer_mode?} if peer_mposts.blank?
    peer_mposts = mposts.to_a if peer_mposts.blank?
    # Extract earliest time
    self.time = (peer_mposts.min_by {|h| h.time}).time unless peer_mposts.empty?
    self.time ||= Time.now
    self.time.utc
    # Extract location
    extract_location(peer_mposts)

    # Create a default name and description
    zone_time = time.in_time_zone(time_zone) # convert to meet local time
    note = ""
    note = (notes.max_by {|h| h[1]})[0] unless notes.empty? # from most common note in users
    if note.present?
      self.name = note # user majority notes
    else
      self.name = format("Meet_%s", zone_time.strftime("%Y-%m-%d"))
    end

    the_address = address
    self.description = format("%s on %s%s%s with %s",
                              note.present? ? note : "Meet",
                              zone_time.strftime("%Y-%m-%d %I:%M%p"),
                              #zone_time.iso8601,
                              has_hoster? ? " hosted by #{hoster.name_or_email}" : "",
                              the_address.present? ? " at #{the_address}" : "",
                              pluralize(unique_users.count, "attandent"))

    # Cache frequently used information into cached_info. Prevent excessive DB queries.
    # The cached information includes: user count, top 10 user ids.
    # Can not call users before it is saved. It may not be availabe and may confuse rails.
    # Instead, count number of users through unique_users.
    self.cached_info ||= Hash.new
    self.cached_info[:users_count] = unique_users.count
    self.cached_info[:top_user_ids] = unique_users.to_a.slice(0..9)
    extract_meet_type
    return self
  end

  # The extra user is manually added. She carry no useful information.
  # Do no update any information except cached_info
  def extract_information_from_extra_user(user)
    # Dirty quick way. To manually add a extra user, the meet must be already there and
    # the user must be new to this meet.
    if !include_user?(user)
      self.cached_info ||= Hash.new
      self.cached_info[:users_count] ||= 0
      cached_info[:top_user_ids] << user.id if cached_info[:top_user_ids].size < 10
      self.cached_info[:users_count] += 1
      extract_meet_type
    end
    return self
  end

  def update_chatters_count
    self.cached_info ||= Hash.new
    topic_ids0, chatter_ids0, photo_ids0 = topic_ids.to_a, chatter_ids.to_a, photo_ids_by_created_at.to_a
    self.cached_info[:topics_count] = topic_ids0.count
    self.cached_info[:chatters_count] = chatter_ids0.count
    self.cached_info[:photos_count] = photo_ids0.count
    self.cached_info[:top_topic_ids] = topic_ids0.slice(0..9)
    self.cached_info[:top_chatter_ids] = chatter_ids0.slice(0..9)
    self.cached_info[:top_photo_ids] = chatter_ids0.slice(0..9)
    return self
  end

  def check_geocode(retries=0) # check geocode information, try to aquire if missing
    extract_geocode(retries) if location.blank?
  end

  def has_hoster?
    return hoster_id?
  end

  def of_type?(of_type)
    return of_type.blank? || meet_type == of_type
  end

  def top_user_ids
    return cached_info[:top_user_ids] || []
  end
  def top_friend_ids(except)
    return (cached_info[:top_user_ids] || []).reject {|v| v==except.id}
  end
  def top_users(user_cache=nil)
    return user_cache ? user_cache.find_user(top_user_ids).compact
                      : User.find(top_user_ids).compact
  end
  def top_friends(except, user_cache=nil)
    return user_cache ? user_cache.find_user(top_friend_ids(except)).compact
                      : User.find(top_friend_ids(except)).compact
  end
  def top_topic_ids
    return cached_info[:top_topic_ids] || []
  end
  def top_topics
    return Chatter.find(top_topic_ids).compact
  end
  def top_chatter_ids
    return cached_info[:top_chatter_ids] || []
  end
  def top_chatters
    return Chatter.find(top_chatter_ids).compact
  end
  def top_photo_ids
    return cached_info[:top_photo_ids] || []
  end
  def top_photos
    return Chatter.find(top_photo_ids).compact
  end
  def users_count
    return cached_info[:users_count] || 0
  end
  def friends_count
    return (users_count - 1).at_least(0) # do not count user herself
  end
  def topics_count
    return cached_info[:topics_count] || 0
  end
  def chatters_count
    return cached_info[:chatters_count] || 0
  end
  def photos_count
    return cached_info[:photos_count] || 0
  end

  def friends(except=nil)
    return except ? users.select {|v| v.id != except.id} : users
  end
  # This is used to get summary information for meets listing.
  def friends_name_list(except, delimiter=", ", max_length=128)
    # Some tricks to improve DB access perfromance.
    # Use user_ids.size instead of users.size to prevent loading of all users within the meet.
    # Also, limit the number of users to be loaded. If it is already fully loaded, do no
    # use limit otherwise it will just result in duplicated loading.
    meet_users = @loaded_top_users ? @loaded_top_users :
                    users.loaded? ? users : User.find(top_friends_ids(except)).compact
    meet_friends = meet_users.select {|user| user.id != except.id}
    friends_name = ""
    friends = Array.new
    more = friends_count
    meet_friends.each {|user|
      user_name = user.name_or_email
      if friends_name.empty?
        friends_name = user_name
        friends << user
        more -= 1
      elsif (friends_name.size + delimiter.size + user_name.size) > max_length
        friends_name += " and #{more} more friends" if more > 0
        break
      else
        friends_name += delimiter + user_name
        friends << user
        more -= 1
      end
    }
    return [friends, friends_name, more]
  end
  def friends_name_list_params=(params)
    @friends_name_list_params = params
  end
  def peers_name_brief
    return friends_name_list(@friends_name_list_params[:except],
                             @friends_name_list_params[:delimiter],
                             @friends_name_list_params[:max_length])[1]
  end

  # User _ids is quick than using associate itself. However, there is a pontential
  # pit fall. If it is a trough relation and some FKs are nil. It will include
  # nil into the _ids array. The associate itself takes care of it but not _ids.
  # Make a sanity check to skip all nil elements
  # Just found another problem, _ids does not honer conditions statement.
  # Have to overwrite the original one.
  def user_ids
    return users.to_a.collect {|v| v.id}.compact
  end
  def deleted_user_ids
    return deleted_users.to_a.collect {|v| v.id}.compact
  end
  def pending_user_ids
    return pending_users.to_a.collect {|v| v.id}.compact
  end
  def include_user?(user)
    return user && user_ids.include?(user.id)
  end
  def include_pending_user?(user)
    return user && pending_user_ids.include?(user.id)
  end
  # Can not purely rely on pending_users's relation. A confirmed one may still show up
  # in pending list. A user may be added after a pending is created. There is no mechanism
  # to promote all related pending requests when a user is added.
  # Have to filter out all users that is already confirmed
  def true_pending_users
    return pending_users.to_a.select {|user| !include_user?(user)}
  end
  def topic_ids
    return Chatter.select(["DISTINCT(id)", "updated_at"])
                  .where("chatters.meet_id = ? AND chatters.topic_id IS NULL", id)
                  .collect {|v| v.id}
  end
  def photo_ids
    return Chatter.select(["DISTINCT(id)", "updated_at"])
                  .where("chatters.meet_id = ? AND chatters.photo_content_type IS NOT NULL", id)
                  .collect {|v| v.id}
  end
  def photo_ids_by_created_at
    return Chatter.select(["DISTINCT(id)", "updated_at", "created_at"])
                  .where("chatters.meet_id = ? AND chatters.photo_content_type IS NOT NULL", id)
                  .sort_by {|v| v.created_at}.reverse.collect {|v| v.id}
  end

  def static_map_url(width=120, height=120, zoom=15, marker="mid")
    return "" unless (lat? && lng?)
    url = "http://maps.google.com/maps/api/staticmap"
    url += "?style=lightness:30|saturation:30||gamma:0.4"
    url += "&zoom=#{zoom}&size=#{width}x#{height}"
    url += "&maptype=roadmap&markers=color:green|size:#{marker}|#{lat},#{lng}&sensor=false"
  end
  def static_map_url_small
    return static_map_url(60, 60, 14, "small")
  end
  def image_url_or_default
    return image_url || "M-small.png"
  end

  def lat_lng
    return (lat?&&lng?) ? "#{lat}, #{lng}" : ""
  end
  def address_or_ll(br)
    loc = address(br)
    return loc.present? ? loc : lat_lng
  end
  def location_or_ll
    return location.present? ? location : address_or_ll
  end
  def time_zone
    zone = time.zone
    return zone unless (lat.present? && lng.present?)
    # Pending ...
    return zone
  end

  def meet_invitation
    return meet_invitations.present? ? meet_invitations.first : nil
  end
  def meet_inviter
    return meet_invitations.present? ? meet_invitations.first.user : nil
  end
  def meet_invitation_message
    return meet_invitations.present? ? meet_invitations.first.message : nil
  end
  def meet_other_inviters
    main_inviter = meet_inviter
    return main_inviter ?
            meet_invitations.collect {|v| v.user}.uniq.reject {|v| v==main_inviter} : []
  end
  def meet_name
    return (meet_mview && meet_mview.name.present?) ? meet_mview.name :
           (hoster_mview && hoster_mview.name.present?) ? hoster_mview.name : ""
  end
  def meet_description
    return (meet_mview && meet_mview.description.present?) ? meet_mview.description :
           (hoster_mview && hoster_mview.description.present?) ? hoster_mview.description : ""
  end
  def meet_time
    return (meet_mview && meet_mview.time.present?) ? meet_mview.time :
           (hoster_mview && hoster_mview.time.present?) ? hoster_mview.time : time;
  end
  def meet_location
    return (meet_mview && meet_mview.location.present?) ? meet_mview.location :
           (hoster_mview && hoster_mview.location.present?) ? hoster_mview.location :
           location
  end
  def meet_address(br=false)
    return (meet_mview && meet_mview.location.present?) ? meet_mview.location :
           (hoster_mview && hoster_mview.location.present?) ? hoster_mview.location :
           address(br)
  end
  def meet_location_or_ll
    return meet_location.present? ? meet_location : location_or_ll
  end
  def meet_address_or_ll(br=false)
    return meet_address.present? ? meet_address(br) : address_or_ll(br)
  end

  def see_or_seen_by?(to)
    return false if !to
    mposts.each {|mpost|
      #next unless mpost.active?
      return true if mpost.see_or_seen_by?(to)
    }
    return false
  end

  def marked_top_users
    return [] if @loaded_top_users.blank?
    res = []
    @loaded_top_users.each {|user|
      res << {:user => user.as_json(UsersController::JSON_USER_DETAIL_API)}
    }
    return res
  end
  def marked_users
    return [] if @loaded_users.blank?
    # Put all new users in front
    @new_users.each {|user| user.is_new_user = true }
    res = []
    @loaded_users.each {|user|
      next if !user.is_new_user
      res << {:user => user.as_json(UsersController::JSON_USER_DETAIL_API)}
    }
    @loaded_users.each {|user|
      next if user.is_new_user
      res << {:user => user.as_json(UsersController::JSON_USER_DETAIL_API)}
    }
    @new_users.each {|user| user.is_new_user = false }
    return res
  end
  # Meet level topics are displayed as comments
  def marked_chatters
    return [] if @loaded_topics.blank?
    res = []
    @new_topics.each {|topic| topic.is_new_chatter = true } if @new_topic.present?
    @loaded_topics.each {|topic|
      res << {:chatter => topic.as_json(ChattersController::JSON_CHATTER_COMMENT_API)}
    }
    @new_topics.each {|topic| topic.is_new_chatter = false } if @new_topic.present?
    return res
  end

private
 
  def extract_location(peer_mposts)
    # Calculate weighted average lng+lat
    lngs, lats, lweights = Array.new, Array.new, Array.new
    # Fist we try to get from mpost with accurate location info, which is defined as error
    # is less than 30feet, 100feet
    [30.0, 100.0, -1.0].each {|val|
      peer_mposts.each {|mpost|
        next unless mpost.active?
        if (mpost.lng? && mpost.lat? && mpost.lerror? &&
            (val <= 0.0 || mpost.lerror < val))
          lngs << mpost.lng
          lats << mpost.lat
          lweights << (1.0/[mpost.lerror,0.01].max)**2
        end
      }
      break unless lngs.empty?
    }
    if !lngs.empty?
      org_lng, org_lat = lng, lat
      self.lng = lngs.mean_sigma_with_weight(lweights)[0]
      self.lat = lats.mean_sigma_with_weight(lweights)[0]
      self.lerror = [(1.0/Math.sqrt(lweights.mean)+0.4999).round,1.0].max
      extract_geocode if (location.blank? || !org_lng || !org_lat ||
                          sqrt((org_lng-lng)**2+(org_lat-lat)**2)/3.5e-6 > 10.0)
    else
      # self.lng, self.lat = nil, nil # keep the original
    end
  end

  def extract_geocode(retries=1)
    return if (!lat? || !lng?)
    geo = nil
    exception_protected(retries) {
      geo = Geokit::Geocoders::GoogleGeocoder::geocode("#{lat}, #{lng}")
    }
    if (geo && geo.success)
      self.location = geo.full_address
      self.street_address = geo.street_name
      self.city = geo.city
      self.state = geo.state
      self.zip = geo.zip
      self.country = geo.country
    end
  end

  def address(br=false)
    address = ""
    if street_address.present?
      brief = street_address.split(",").last
      brief = street_address if brief.blank?
      brief.strip!
      address += "#{brief},"
      address += br ? "<br>" : " "
    end
    address += "#{city}, " if city.present?
    address += "#{state}" if state.present?
    return address
  end

  def extract_meet_type
    self.meet_type = users_count == 1 ? 1 :
                     users_count == 2 ? 2 :
                     users_count >= 3 ? 3 : 0
    return self
  end

  def collision?
    return !collision.nil? && collision != 0 && collision != false
  end

end
