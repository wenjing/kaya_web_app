# == Schema Information
# Schema version: 20110227025014
#
# Table name: meets
#
#  id             :integer         primary key
#  name           :string(255)
#  description    :text
#  time           :timestamp
#  location       :string(255)
#  street_address :string(255)
#  city           :string(255)
#  state          :string(255)
#  zip            :string(255)
#  country        :string(255)
#  image_url      :string(255)
#  created_at     :timestamp
#  updated_at     :timestamp
#  lng            :decimal(, )
#  lat            :decimal(, )
#  lerror         :float
#  collision      :boolean
#  host_id        :string(255)
#  lock_version   :integer         default(0), not null
#  hoster_id      :integer
#  cached_info    :text
#  meet_type      :integer
#  cirkle_id      :integer
#

require 'geokit'
require 'kaya_base'

class Meet < ActiveRecord::Base
  after_create :record_avg_meet_lag

  attr_accessor :meet_mview, :hoster_mview
  attr_accessor :loaded_top_users, :loaded_top_chatters
  attr_accessor :meet_invitations
  attr_accessor :loaded_users, :loaded_topics, :new_user_ids, :new_topic_ids,
                :is_new_invitation, :is_new_encounter, :is_first_encounter
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

  has_many :encounters, :class_name => "Meet", :foreign_key => "cirkle_id",
                        :inverse_of => :cirkle
  belongs_to :cirkle, :class_name => "Meet", :inverse_of => :encounters

  has_many :chatters, :dependent => :destroy, :inverse_of => :meet
  has_many :topics, :class_name => "Chatter",
                    :conditions => ['chatters.topic_id IS NULL']
  has_many :photos, :class_name => "Chatter",
                    :conditions => ['chatters.photo_content_type IS NOT NULL']
# has_many :latest_chatters, :class_name => "Chatter", :limit => 3,
#                   :conditions => ['chatters.content IS NOT NULL AND chatters.content != ?', ""]

  has_many :invitations, :dependent => :destroy, :inverse_of => :meet
  has_many :mviews, :dependent => :destroy, :inverse_of => :meet

  #accepts_nested_attributes_for :chatters, :reject_if => :all_blank, :allow_destroy => true

  validates :name,  :presence => true, :length   => { :maximum => 250 }
  validates :time,  :presence => { :message => "date time missing or unrecognized format" }
  validates :lng,   :numericality => { :greater_than_or_equal_to => BigDecimal("-180.0"),
                                       :less_than_or_equal_to    => BigDecimal(" 180.0"),
                                       :allow_nil => true }
  validates :lat,   :numericality => { :greater_than_or_equal_to => BigDecimal("-90.0"),
                                       :less_than_or_equal_to    => BigDecimal(" 90.0"),
                                       :allow_nil => true }

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

  def extract_information(new_mposts = [], deleted_mposts = [])
    # Extract meeting time (average time)
    #self.class.benchmark("Extract meet information") do
    self.collision = false if collision.nil?
    mpost_cirkle_id = nil
    if !collision
      # Do not check collision and cirkles on deleted mposts and non-peer mode mposts
      # Detect conflicting cirkle_ids, get proper cirkle_id if no confilcts
      mposts.each {|mpost|
        next if (mpost.deleted? || !mpost.is_peer_mode?)
        if mpost.collision?
          self.collision = true
          break
        elsif mpost.cirkle_id
          if (mpost_cirkle_id && mpost_cirkle_id != mpost.cirkle_id)
            self.collision = true
          else
            mpost_cirkle_id = mpost.cirkle_id
          end
        end
      }
    end
    unique_users = Set.new
    notes = Hash.new
    mposts.each {|mpost|
      if (collision && !mpost.deleted?)
        deleted_mposts << mpost
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
    #some information for them to proceed correctly.
#   if collision
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
    self.cached_info[:top_user_ids] = unique_users.to_a.first(10)
    extract_meet_type

    # Finally, extract cirkle information from it
    #cirkle0 = cirkle_id ? Meet.find_by_id(cirkle_id) : nil
    cirkle0 = cirkle
    if !collision?
      if !mpost_cirkle_id
        # Case 1, no cirkle id specified in any of mposts. Create one from the meet automatically
        if (!cirkle0 && meet_type == 3) # No automatic cirkle for solo and private encounters
          cirkle0 = Meet.create_cirkle_from_encounters([self])
        elsif cirkle0
          cirkle0.add_encounters([self], new_mposts)
        end
      else # Case 2, cirkle id specified. Add the meet to cirkle
        if (cirkle0 && cirkle_id != mpost_cirkle_id)
          # A special case, cirkle id specified, but an cirkle was already automatically created
          # because it was initially identified as first_encounter (no cirkle specified in all mposts).
          if (crikle0.encounters.count == 1 && crikle0.encounters.first.id = id)
            # Removes the orginal cirkle first if this encounter is the only one in it.
            crikle0.destroy
          end
          self.cirkle = nil
          cirkle0 = nil
        end
        if !cirkle0
          cirkle0 = Meet.find_by_id(mpost_cirkle_id)
          # Because no cirkle created yet, mark all mposts as new mposts
          new_mposts = mposts
        end
        if (cirkle0 && cirkle0.is_cirkle?)
          cirkle0.add_encounters([self], new_mposts)
        end
      end
    elsif cirkle0
      # This encounter has been removed, remove it from cirkle.
      new_mpost_ids = new_mposts.collect {|v| v.id}.to_set
      cirkle0.delete_encounters([self], deleted_mposts.select {|v| !new_mpost_ids.include?(v.id)})
    end
    #end
    return self
  end
  def delete_encounters(encounters0, encounters_mposts0)
    cirkle_mposts0 = nil
    self.opt_lock_protected {
      cirkle_mposts0 = Set.new
      user_cirkle_mposts = mposts.group_by {|v| v.user_id}
      unique_users = user_cirkle_mposts.keys.to_set
      encounters_mposts0.each {|mpost|
        cirkle_mposts = user_cirkle_mposts[mpost.user_id]
        cirkle_mposts.each {|cirkle_mpost|
          cirkle_mpost.cirkle_ref_count -= 1
          if cirkle_mpost.cirkle_ref_count <= 0
            # All encounters with this user is deleted by collision, remove her from cirkle.
            cirkle_mpost.delete
            unique_users.delete(cirkle_mpost.user_id)
            cirkle_mposts0 << cirkle_mpost
          end
        } if cirkle_mposts.present?
      }
      encounters0.each {|encounter0|
        #encounter0.opt_lock_protected {
          encounter0.cirkle = nil
          #encounter0.save
        #}
      }
      self.cached_info[:users_count] = unique_users.size
      self.cached_info[:top_user_ids] = unique_users.to_a.first(10)
      save
    }
    cirkle_mposts0.each {|mpost| mpost.save}
    return self
  end

  # The extra user is manually added. She carry no useful information.
  # Do no update any information except cached_info
  def extract_information_from_extra_user(user0, new_mposts)
    # Dirty quick way. To manually add an extra user, the meet must be already there and
    # the user must be new to this meet.
    self.cached_info ||= Hash.new
    self.cached_info[:users_count] ||= 0
    cached_info[:top_user_ids] << user0.id if cached_info[:top_user_ids].size < 10
    self.cached_info[:users_count] += 1
    if is_encounter?
      extract_meet_type
      #cirkle0 = cirkle_id ? Meet.find_by_id(cirkle_id) : nil
      cirkle0 = cirkle
      cirkle0.add_encounters([self], new_mposts) if cirkle0
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
    self.cached_info[:top_photo_ids] = photo_ids0.slice(0..9)
    return self
  end

  def check_geocode(retries=0) # check geocode information, try to aquire if missing
    extract_geocode(retries) if location.blank?
  end

  def has_hoster?
    return hoster_id?
  end

  def of_type?(type)
    return type.blank? || meet_type == type || type.include?(type)
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

  def user_ids
    return Mpost.select(["user_id", "created_at"])
                  .where("meet_id = ? AND status = ?", id, 0)
                  .collect {|v| v.user_id}.uniq.compact
    #return users.to_a.collect {|v| v.id}.compact
  end
  def deleted_user_ids
    return Mpost.select(["user_id", "created_at"])
                  .where("meet_id = ? AND status = ?", id, 1)
                  .collect {|v| v.user_id}.uniq.compact
    #return deleted_users.to_a.collect {|v| v.id}.compact
  end
  def pending_user_ids
    return Mpost.select(["user_id", "created_at"])
                  .where("meet_id = ? AND status = ?", id, 2)
                  .collect {|v| v.user_id}.uniq.compact
    #return pending_users.to_a.collect {|v| v.id}.compact
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
    return Chatter.select(["id", "updated_at"])
                  .where("chatters.meet_id = ? AND chatters.topic_id IS NULL", id)
                  .collect {|v| v.id}
  end
  def photo_ids
    return Chatter.select(["id", "updated_at"])
                  .where("chatters.meet_id = ? AND chatters.photo_content_type IS NOT NULL", id)
                  .collect {|v| v.id}
  end
  def photo_ids_by_created_at
    return Chatter.select(["id", "updated_at", "created_at"])
                  .where("chatters.meet_id = ? AND chatters.photo_content_type IS NOT NULL", id)
                  .sort_by {|v| v.created_at}.reverse.collect {|v| v.id}
  end

  def static_map_url(width=120, height=120, zoom=15, marker="mid")
    return "" unless (lat.present? && lng.present?)
    url = "http://maps.google.com/maps/api/staticmap"
    url += "?style=lightness:30|saturation:30||gamma:0.4"
    url += "&zoom=#{zoom}&size=#{width}x#{height}"
    url += "&maptype=roadmap&markers=color:green|size:#{marker}|#{lat},#{lng}&sensor=false"
  end
  def static_map_url_small
    return static_map_url(54, 54, 14, "small")
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
    res = []
    @loaded_users.each {|user|
      # List new users first
      if @new_user_ids.include?(user.id)
        user.is_new_user = true
        res << {:user => user.as_json(UsersController::JSON_USER_DETAIL_API)}
        user.is_new_user = nil
      end
    }
    @loaded_users.each {|user|
      if !@new_user_ids.include?(user.id)
        user.is_new_user = false
        res << {:user => user.as_json(UsersController::JSON_USER_DETAIL_API)}
        user.is_new_user = nil
      end
    }
    return res
  end
  def marked_chatters
    return [] if @loaded_topics.blank?
    res = []
    @loaded_topics.each {|topic|
      topic.is_new_chatter = @new_topic_ids.include?(topic.id)
      if is_cirkle?
        res << {:chatter => topic.as_json(ChattersController::JSON_CHATTER_MARKED_DETAIL_API)}
      else
        # Encounter level topics are displayed as comments
        res << {:chatter => topic.as_json(ChattersController::JSON_CHATTER_MARKED_COMMENT_API)}
      end
      topic.is_new_chatter = nil
    }
    return res
  end

  def collision?
    return !collision.nil? && collision != 0 && collision != false
  end

  # Meet creation lag from the time when the first mpost was received
  def record_avg_meet_lag
    stats = Stats.first || Stats.new
    stats.update_avg_meet_lag(self)
    stats.save
  end
  def meet_lag
    first_mpost = mposts.last
    return 0.0 unless (created_at && first_mpost)
    lag = created_at - first_mpost.created_at
    return lag.at_least(0.0)
  end

  # Cirkle related functions
  def is_cirkle?
    return meet_type > 3
  end
  def is_encounter?
    return !is_cirkle?
  end

  def add_encounters(encounters0, encounters_mposts0)
    cirkle_mposts0 = nil
    self.opt_lock_protected {
      new_users = Set.new
      cirkle_mposts0 = Set.new
      encounter_users = encounters_mposts0.collect {|v| v.user_id}.to_set
      user_cirkle_mposts = id ? Mpost.where('user_id IN (?) AND meet_id = ?', encounter_users, id)
                                     .group_by(&:user_id) : {}
      encounters_mposts0.each {|mpost|
        cirkle_mposts = user_cirkle_mposts[mpost.user_id]
        if cirkle_mposts.blank?
          cirkle_mpost = Mpost.new
          cirkle_mpost.note = mpost.note
          cirkle_mpost.time = mpost.time
          cirkle_mpost.lat = mpost.lat
          cirkle_mpost.lng = mpost.lng
          cirkle_mpost.lerror = mpost.lerror
          cirkle_mpost.devs = Mpost::CIRKLE_MARKER
          cirkle_mpost.user_dev = Mpost::CIRKLE_MARKER
          cirkle_mpost.host_id = Mpost::CIRKLE_MARKER
          cirkle_mpost.cirkle_ref_count = 0
          cirkle_mpost.user_id = mpost.user_id
          new_users << mpost.user_id # Add user to the cirkle
          cirkle_mposts = [cirkle_mpost]
          user_cirkle_mposts[mpost.user_id] = cirkle_mposts
        end
        cirkle_mposts.each {|cirkle_mpost|
          cirkle_mpost.cirkle_ref_count += 1
          cirkle_mpost.recovery # If it is pending, confirm it; if removed, recovery back
          cirkle_mposts0 << cirkle_mpost
        }
      }
      self.cached_info[:users_count] ||= 0
      self.cached_info[:top_user_ids] ||= []
      self.cached_info[:users_count] += new_users.size
      self.cached_info[:top_user_ids].concat(new_users.to_a).slice!(10..-1)
      save
    }
    encounters0.each {|encounter0|
      next if encounter0.cirkle_id == id
      #encounter0.opt_lock_protected {
        encounter0.cirkle = self
        if meet_type == 6
          # Once assigned to a group_cirkle, force all encounters' type to group_encounter
          encounter0.meet_type = 3
        end
        #encounter0.save
      #}
    }
    cirkle_mposts0.each {|cirkle_mpost| cirkle_mpost.meet_id = id; cirkle_mpost.save}
    return self
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
        if (mpost.lng.present? && mpost.lat.present? && mpost.lerror.present? &&
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
      extract_geocode if (location.blank? || org_lng.blank? || org_lat.blank? ||
                          sqrt((org_lng-lng)**2+(org_lat-lat)**2)/3.5e-6 > 10.0)
    else
      # self.lng, self.lat = nil, nil # keep the original
    end
  end

  def extract_geocode(retries=1)
    return if (!lat.present? || !lng.present?)
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

  def self.create_cirkle_from_encounters(encounters0)
    return [] if encounters0.empty?
    cirkle0 = Meet.new
    cirkle0.meet_type = 6
    cirkle0.cached_info ||= Hash.new
    first_encounter = encounters0.min_by {|v| v.time}
    # Clone meet information from first encounter
    cirkle0.description ||= first_encounter.description
    cirkle0.name ||= first_encounter.name
    cirkle0.time ||= first_encounter.time
    cirkle0.location ||= first_encounter.location
    cirkle0.street_address ||= first_encounter.street_address
    cirkle0.location ||= first_encounter.location
    cirkle0.city ||= first_encounter.city
    cirkle0.zip ||= first_encounter.zip
    cirkle0.country ||= first_encounter.country
    cirkle0.image_url ||= first_encounter.image_url
    cirkle0.lat ||= first_encounter.lat
    cirkle0.lng ||= first_encounter.lng
    cirkle0.lerror ||= first_encounter.lerror
    cirkle0.collision ||= false
    encounters_mposts0 = []
    encounters0.each {|encounter0|
      encounters_mposts0.concat(encounter0.mposts)
    }
    cirkle_mposts = cirkle0.add_encounters(encounters0, encounters_mposts0)
    return cirkle0
  end

end
