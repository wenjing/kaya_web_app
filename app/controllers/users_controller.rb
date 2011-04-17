class UsersController < ApplicationController
  before_filter :store_return_point, :only => [:show, :pending_meets, :friends, :meets, :map]
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:create, :update] do |controller|
    controller.filter_params(:user, :strip => [:email])
  end
  before_filter :authenticate, :except => [:new, :create, :edit, :update]
  before_filter :authenticate_pending_ok, :only => [:edit, :update]
  before_filter :only => [:create] do |controller|
    signed_in? || basic_authenticate
  end
  before_filter :correct_user, :only => [:edit, :update, :pending_meets, :confirm_meets,
                                         :friends, :cirkles, :news]
  before_filter :admin_current_user,     :only => [:index]
  before_filter :admin_user_except_self, :only => [:destroy]
  
  JSON_USER_DETAIL_API = { :except => [:created_at, :admin, :lock_version, :status, :updated_at,
                                       :salt, :encrypted_password, :temp_password,
                                       :photo_content_type, :photo_file_name,
                                       :photo_file_size, :photo_updated_at],
                           :methods => [:user_avatar, :is_new_user] }
  JSON_USER_BRIEF_API = { :except => [:created_at, :admin, :lock_version, :status, :updated_at,
                                       :salt, :encrypted_password, :temp_password, #:email,
                                       :photo_content_type, :photo_file_name,
                                       :photo_file_size, :photo_updated_at],
                           :methods => [:user_avatar, :is_new_user] }
  JSON_USER_LIST_API = JSON_USER_BRIEF_API

  def index
    assert_unauthorized(false, :except=>:html)
    respond_to do |format|
      format.html {
        @users = User.paginate(:page => params[:page], :per_page => 25)
        @title = "All users"
      }
    end
  end
 
  # User home when user signed in.
  # Display aggregate user info, recent meets, related chatter, friends and maybe a small map
  def show
    # Do not use costly eager load to get all meets/chatters/friends. We only need
    # to get a top listed few.
    @user = find_user(params[:id])
    assert_internal_error(@user)
    respond_to do |format|
      format.html {
        #@meets = @user.top_meets(15) # Get a bit more to make sure we have enough top friends
        #@friends = @user.top_friends(@meets, 15)
        #@chatters = @user.top_chatters(10)
        #@meets = @meets.slice(0..4)
        #attach_meet_infos(current_user, @meets)
        @title = @user.name_or_email
        redirect_to meets_user_path(@user)
      }
      format.json { # Only return user profile
        if (!current_user?(@user) && !admin_user?)
          render :json => @user.to_json(JSON_USER_BRIEF_API)
        else
          render :json => @user.to_json(JSON_USER_DETAIL_API)
        end
      }
    end
  end

  # Pending meet list view
  def pending_meets 
    assert_internal_error(@user)
    @pending_meets = @user.true_pending_meets
    respond_to do |format|
      format.html {
        # redirect back to user meets view if no more pending meets
        if @pending_meets.empty?
          redirect_back user_meets_path(@user)
        else
          @pending_meets = @pending_meets.paginate(:page => params[:page], :per_page => 25)
          attach_meet_infos(current_user, @pending_meets, true)
        end
      }
      format.json {
        cursor = params[:cursor] || params
        @pending_meets = @pending_meets.cursorize(cursor,
                                  :only=>[:time, :created_at, :updated_at, :lat, :lng])
        attach_meet_infos(current_user, @pending_meets, true)
        @pending_meets.each {|meet|
          meet.friends_name_list_params = {:except=>current_user,:delimiter=>", ",:max_length=>80}
        }
        render :json => @pending_meets.to_json(MeetsController::JSON_PENDING_MEET_LIST_API)
      }
    end
  end

  # Meet list view
  def meets
    @user = find_user(params[:id])
    assert_unauthorized(@user)
    @meet_type = params[:meet_type] ? params[:meet_type].to_i : nil
    #meet_types = [@meet_type, @meet_type+3] if @meet_type
    meet_types = @meet_type ? (@meet_type > 0 ? [@meet_type] : [1, 2, 3, 4, 5, 6]) : [1, 2, 3]
    with_user = admin_user? ? @user : current_user
    @meets = @user.meets_with(with_user, meet_types)
    respond_to do |format|
      format.html {
        @pending_meet_count = @user.true_pending_meets.count
        @meets = @meets.paginate(:page => params[:page], :per_page => 20)
        attach_meet_infos(current_user, @meets)
        @title = @user.name_or_email
      }
      format.json {
        cursor = params[:cursor] || params
        @meets = @meets.cursorize(cursor, :only=>[:time, :created_at, :updated_at, :lat, :lng])
        attach_meet_infos(current_user, @meets)
        # This params staff is the workaround for to_json because :methods can not specify parameters. 
        # We can not hardcode :except (which is used to prevent display user herself in the list).
        @meets.each {|meet|
          meet.friends_name_list_params = {:except=>current_user,:delimiter=>", ",:max_length=>80}
        }
        render :json => @meets.to_json(MeetsController::JSON_MEET_LIST_APIX)
      }
    end
  end

  # Friends list view
  def friends
    # Here, not only eager load all meets but also all users under each meet
    # Includes with duplicated through relation is buggy. Event with uniq specified, it returns
    # duplicated meets, users list
    #@user = User.includes(:meets).find_by_id(params[:id])
    assert_internal_error(@user)
    # Beside cursor, also support sorting.
    # Support following sorting methods:
    #  1) By time, recent met first
    #  2) By relation, most common meets first
    cursor = params[:cursor] || params
    sort_by = cursor[:sort_by]

    # meet_friends returns a hash user=>[meets]
    # After sort, it becomes array [user, [meets]]
    @friends = []
    friends_meets = @user.friends_meets(nil, nil, [:id,:time,:lat,:lng], nil, self, false)
    if sort_by == "relation"
      @friends = friends_meets.sort {|x, y|
        tt = -(x[1].size <=> y[1].size) # compare relation first, DESC order
        # then base on name
        tt = (x[0].name_or_email <=> y[0].name_or_email) if tt == 0
        tt
      }
    else # sort by meet time, this is default
      @friends = friends_meets.sort {|x, y|
        tt = -(x[1][0].time <=> y[1][0].time) # compare time first, DESC order
        # then base on name
        tt = (x[0].name_or_email <=> y[0].name_or_email) if tt == 0
        tt
      }
    end

    respond_to do |format|
      format.html {
        @friends = @friends.paginate(:page => params[:page], :per_page => 25)
        @title = @user.name_or_email
      }
      format.json {
        @friends = @friends.cursorize(cursor)
        @friends = @friends.collect {|v| [v[0], v[1].size, v[1][0].time]}
        render :json => friends.to_json(JSON_USER_LIST_API)
      }
    end
  end

  # Cirkle list view
  def cirkles
    self.class.benchmark("Create friends/cirkle list") do
    summary_limit = 4
    #@user = User.includes(:meets).find_by_id(params[:id])
    assert_internal_error(@user)
    cursor = params[:cursor] || params
    after_time = cursor[:after_time] ? Time.zone.parse(cursor[:after_time]) : nil
    #before_time = cursor[:before_time] ? Time.zone.parse(cursor[:before_time]) : nil
    #limit = cursor[:limit] ? cursor[:limit].to_i : nil

    current_time = Time.now.getutc
    contents = []
    api_contents = []
    meets0 = @user.all_meets # these include both encounters and cirkles

    self.class.benchmark("Create") do
    has_update = !after_time.present?
    if !has_update
      has_update = @user.updated_at >= after_time
    end
    if !has_update
      has_update = meets0.where("meets.updated_at >= ?", after_time).first.present?
    end
    if !has_update
      has_update = @user.mposts.where("mposts.updated_at >= ?", after_time).first.present?
    end
    if !has_update
      has_update = @user.mviews.where("mviews.updated_at >= ?", after_time).first.present?
    end

    if has_update
      # Also load all cirkles these meets refering to, so we don't have to load
      # them one-by-one when needed.
      #loaded_meet_ids = meets0.collect {|v| v.id}.to_set
      #cirkle_ids = meets0.collect {|v| v.cirkle_id}.uniq.compact
      #missing_cirkle_ids = cirkle_ids.select {|v| !loaded_meet_ids.include?(v)}
      #if missing_cirkle_ids.present?
      #  missing_meets = Meet.where('id IN (?)', missing_cirkle_ids)
      #end
      #encounters0 = meets0.select {|v| v.is_encounter?}
      #cirkles0 = meets0.select {|v| v.is_cirkle?}

      meets0 = meets0.to_a

      # Mark pending and deleted flag in meet
      pending_meet_ids = @user.true_pending_meet_ids.to_set
      deleted_meet_ids = @user.true_deleted_meet_ids.to_set
      meets0.each {|v|
        v.is_pending = true if pending_meet_ids.include?(v.id)
        v.is_deleted = true if deleted_meet_ids.include?(v.id)
      }

      # Get all none-participant meets, but under same cirkles
      cirkle_ids = meets0.select {|v| v.is_cirkle?}.collect {|v| v.id}
      meet_ids = meets0.collect {|v| v.id}
      other_meets = Meet.where("meets.cirkle_id IN (?)", cirkle_ids)
                        .where("meets.id NOT IN (?)", meet_ids)
      meets0.concat(other_meets)

      # top_photo_ids shall already sorted by created_at, so only get the top count list
      photo_ids = []
      meets0.each {|meet| photo_ids.concat(meet.top_photo_ids.first(summary_limit)) }
      photos = find_chatters(photo_ids)

      #solo_meets = meets0.select {|v| v.meet_type == 1 || v.meet_type == 4}
      #private_meets = meets0.select {|v| v.meet_type == 2 || v.meet_type == 5}
      #group_meets = meets0.select {|v| v.meet_type == 3 || v.meet_type == 6}
      # Everything is now group cirkle.
      solo_meets = []
      private_meets = []
      group_meets = meets0.select {|v| v.meet_type != 0}

      # Solo
      if !solo_meets.empty?
        # Still need all solo meets, not only the filtered ones
        content = ContentAPI.new(:solo)
        content.timestamp = solo_meets.collect {|v| v.updated_at}.max
        content.id = @user.id
        content.body = {}
        content.body[:user] = @user
        content.body[:relation_score] = [current_time, 1]
        content.body[:activities_summary] = get_activities_summary(summary_limit, solo_meets, photos)
        contents << content
      end

      # Private
      # If after_updated_at is specified, friends_meets here do not include all meets.
      if !private_meets.empty?
        # Do not use private cirkles because they are created on demand when
        # direct chatter established between them. Get friends list from all
        # encounters (do not count cirkles, not a friend unless met directly).
        #friends_meets = @user.friends_meets(meets0, nil, nil, nil, self, false)
        # Nail down priviate contents to only private groups, no more contents from cirkles.
        friends_meets = @user.friends_meets(private_meets, nil, nil, nil, self, true)

        private_contents = []
        friends = friends_meets.collect {|v| v[0]}
        friends_stats = get_friends_stats(friends, meets0)
        friends_meets.each_pair {|friend, with_meets|
          next if with_meets.empty?
          friend_stats = friends_stats[friend]
          next unless friend_stats
          content = ContentAPI.new(:private)
          content.timestamp = with_meets.collect {|v| v.updated_at}.max
          content.id = friend.id
          content.body = {}
          content.body[:user] = friend
          content.body[:encounter_count] = friend_stats[:encounter_count]
          content.body[:last_encounter_time] = friend_stats[:last_encounter_time]
          content.body[:relation_score] = friend_stats[:relation_score]
          content.body[:activities_summary] = get_activities_summary(summary_limit, with_meets, photos)
          private_contents << content
        }
        private_contents.sort_by! {|v| [v.body[:relation_score], (current_time-v.timestamp)]}
        contents.concat(private_contents)
      end

      # Cirkle (Group)
      if !group_meets.empty?
        cirkle_contents = []
        cirkles_meets = get_cirkles_meets(group_meets)
        cirkles_stats = get_cirkles_stats(cirkles_meets.collect {|v| v[0]}, meets0)
        cirkles_meets.each_pair {|cirkle, cirkle_meets|
          next if cirkle_meets.empty?
          cirkle_stats = cirkles_stats[cirkle]
          content = ContentAPI.new(:cirkle)
          content.timestamp = cirkle_meets.collect {|v| v.updated_at}.max
          content.id = cirkle.id
          content.body = {}
          content.body[:cirkle] = cirkle if cirkle
          content.body[:encounter_count] = cirkle_stats[:encounter_count]
          content.body[:last_encounter_time] = cirkle_stats[:last_encounter_time]
          content.body[:relation_score] = cirkle_stats[:relation_score]
          content.body[:activities_summary] = get_activities_summary(summary_limit, cirkle_meets, photos)
          cirkle_contents << content
        }
        cirkle_contents.sort_by! {|v| [v.body[:relation_score], (current_time-v.timestamp)]}
        contents.concat(cirkle_contents)
      end
    end
 
    # Filter by timestamp
#   contents = contents.select {|content|
#     is_between_time?(content.timestamp, after_time, nil)
#   }
    attach_meet_infos_to_contents(contents, meets0.any? {|v| v.is_pending})

    # Simplify API contents
    contents.each {|content|
      api_content = ContentAPI.new(content.type)
      api_content.id = content.id
      api_content.timestamp = content.timestamp
      api_content.body = {}
      if (content.type == :solo || content.type == :private)
        user0 = content.body[:user]
        api_content.body[:name] = user0.name_or_anonymous
        api_content.body[:user] = user0
      else
        cirkle0 = content.body[:cirkle]
        api_content.body[:name] = cirkle0.marked_name
        #api_content.body[:user] = cirkle0.loaded_top_users.first
        api_content.body[:image] = cirkle0.marked_image
        meet_invitation = cirkle0.is_pending ? cirkle0.meet_invitation : nil
        if meet_invitation
          api_content.body[:is_pending] = true
          api_content.body[:inviter] = meet_invitation.user.as_json(UsersController::JSON_USER_LIST_API)["user"]
          api_content.body[:invite_message] = meet_invitation.message
        end
        if cirkle0.is_deleted
          api_content.body[:is_deleted] = true
        end
      end
      api_content.body[:relation_score] = content.body[:relation_score][1]
      activities = []
      content.body[:activities_summary].each {|activity_summary|
        activity = {}
        if activity_summary.type == :photo
          photo0 = activity_summary.body[:photo]
          activity = {:type=>:photo, :content=>photo0.content,
                      :timestamp=>activity_summary.timestamp, :url=>photo0.chatter_photo}
          if photo0.loaded_user.present?
            activity[:user] = photo0.loaded_user.as_json(UsersController::JSON_USER_LIST_API)["user"]
          end
        else
          encounter0 = activity_summary.body[:encounter_summary]
          name0 = encounter0.marked_name
          activity = {:type=>:encounter, :name=>name0,
                      :timestamp=>activity_summary.timestamp,
                      :lng=>encounter0.lng, :lat=>encounter0.lat}
        end
        activities << activity
      }
      api_content.body[:activities] = activities
      api_contents << api_content
    }
    api_contents.sort_by! {|v| [(current_time-v.timestamp), v.body[:name]]}

    end
    self.class.benchmark("View") do
      respond_to do |format|
        format.html { }
        format.json { render :json => api_contents }
      end
    end
    end
  end

  def news
    self.class.benchmark("Create news") do

    #@user = User.includes(:meets).find_by_id(params[:id])
    assert_internal_error(@user)
    if params[:user_id].present?
      @with_user = find_user(params[:user_id])
      assert_unauthorized(@with_user)
    end
    if params[:cirkle_id].present?
      @cirkle = find_meet(params[:cirkle_id])
      assert_unauthorized(@cirkle && @cirkle.is_cirkle?)
    end
    cursor = params[:cursor] || params
    after_time = cursor[:after_time] ? Time.zone.parse(cursor[:after_time]) : nil
    before_time = cursor[:before_time] ? Time.zone.parse(cursor[:before_time]) : nil
    limit = cursor[:limit] ? cursor[:limit].to_i : nil

    # Content item types:
    #   New collision (always on top)
    #   All pending Invitations (always on top)
    #   New pending Invitation
    #   New Cirkle
    #   New Encounter
    #   New Topic/comments
    #   New Invitation and Invitation confirmation (3rd person)
    current_time = Time.now.getutc
    top_contents = []
    contents = []

    mposts0 = @user.mposts.where('')
    mposts0 = mposts0.where("updated_at >= ?", after_time) if after_time
    mposts0 = mposts0.where("updated_at <= ?", before_time) if before_time
    meets0 = @user.meets.where('')
    meets0 = meets0.where("meets.updated_at >= ?", after_time) if after_time
    meets0 = meets0.where("meets.updated_at <= ?", before_time) if before_time
    meets0 = meets0.where("meets.cirkle_id = ? OR meets.id = ?", @cirkle.id, @cirkle.id) if @cirkle

    self.class.benchmark("Create") do
    meets0 = meets0.to_a
    if !meets0.empty?
      # Also load all cirkles these meets refering to, so we don't have to load
      # them one-by-one when needed.
      loaded_meet_ids = meets0.collect {|v| v.id}.to_set
      cirkle_ids = meets0.collect {|v| v.cirkle_id}.uniq.compact
      missing_cirkle_ids = cirkle_ids.select {|v| !loaded_meet_ids.include?(v)}
      if missing_cirkle_ids.present?
        meets0.concat(Meet.where('id IN (?)', missing_cirkle_ids))
      end
      mposts0 = mposts0.where("meet_id IN (?)", meets0.collect {|v| v.id})

      # Get all none-participant meets, but under same cirkles
      cirkle_ids = meets0.select {|v| v.is_cirkle?}.collect {|v| v.id}
      meet_ids = meets0.collect {|v| v.id}
      other_meets = Meet.where("meets.cirkle_id IN (?)", cirkle_ids)
                        .where("meets.id NOT IN (?)", meet_ids)
      other_meets = other_meets.where("meets.updated_at >= ?", after_time) if after_time
      other_meets = other_meets.where("meets.updated_at <= ?", before_time) if before_time
      meets0.concat(other_meets)
    end

    # Collisions, only for non-flashback mode
    deleted_mposts0 = mposts0.select {|mpost| mpost.status == 1}
    if (!@with_user && !@cirkle && !deleted_mposts0.empty?)
      deleted_mposts0.each {|mpost|
        next if mpost.processing_status != 2
        content = ContentAPI.new(:collision)
        content.timestamp = mpost.updated_at
        content.id = mpost.id
        content.body = {:mpost => mpost}
        top_contents << content
      }
    end

    if false # moved to cirkles
    # All pending Invitations & New pending Invitation
    # If any mpost with invitation_id changed, it hints potential invitation activities.
    # Need to send updated pending_meets list to client.
    invited_mposts0 = mposts0.select {|mpost| mpost.invitation_id.present?}
    # Not for user-flashback mode. Apparently, no invitation for solo and private relations.
    if (!@with_user && invited_mposts0.first.present?)
      pending_meets0 = get_pending_meets(@user, @cirkle)
      attach_meet_invitations(@user, pending_meets0)
      # All pending Invitations
      content = ContentAPI.new(:pending_invitations)
      #content.timestamp = Time.now.utc
      # To garantee the invitations are always displayed first and it has
      # only once placeholder, fix the timestamp to a far future time.
      content.timestamp = Time.zone.parse("2035-01-01 00:00:00 UTC")
      content.id = 0
      content.body = []
      pending_invitations = []
      pending_meets0.each {|pending_meet|
        pending_meet.is_new_invitation =
            (!after_time && !before_time) ||
            is_between_time?(pending_meet.meet_invitation.created_at, after_time, before_time)
        pending_invitations << pending_meet
      }
      content.body = {:pending_invitations => pending_invitations}
      top_contents << content
      # New pending Invitation
      pending_meets0.select {|v| v.is_new_invitation}.each {|pending_meet|
        content = ContentAPI.new(:pending_invitation)
        content.timestamp = pending_meet.meet_invitation.created_at
        content.id = pending_meet.id
        content.body = {:pending_invitation => pending_meet}
        contents << content
      }
    end
    end

    if @with_user
      if (@with_user.id == @user.id) # only solo meets
        meets0 = meets0.select {|meet| meet.meet_type == 1 || meet.meet_type == 4}
      else # all meets with the user
        with_meet_ids = @with_user.meet_ids.to_set
        meets0 = meets0.select {|meet|
          # Get common encounters and common private cirkles
          # with_meet_ids.include?(meet.id) && (meet.is_encounter? || meet.meet_type == 5)
          # Similar to cirkles API, only include private meets
          with_meet_ids.include?(meet.id) && (meet.meet_type == 2 || meet.meet_type == 5)
        }
      end
    end

    if !meets0.empty?
      encounters0 = meets0.select {|v| v.is_encounter?}
      cirkles0 = meets0.select {|v| v.is_cirkle?}
      cirkles_stats = get_cirkles_stats(cirkles0, meets0)
      attach_meet_details(@user, meets0, cirkles0, encounters0, before_time, after_time)

      # Cirkle members
      if @with_user || @cirkle
        content = ContentAPI.new(:users)
        content.timestamp = Time.zone.parse("2035-01-01 00:00:00 UTC")
        content.id = 0
        content.body = {}
        users = []
        if @with_user
          users << @user
          users << @with_user if @with_user.id != @user.id
        else
          users = cirkles0.find {|v| v.id == @cirkle.id}.loaded_users
        end
        content.body[:users] = users.as_json(UsersController::JSON_USER_DETAIL_API)
        contents << content
      end

      # New Encounter
      cirkles0 = cirkles0.index_by(&:id)
      encounters0.each {|meet|
        # only new encounters or encounters with new chatters
        next unless (meet.is_new_encounter || !meet.new_topic_ids.empty?)
        content = ContentAPI.new(:encounter)
        latest_activity_time = meet.loaded_topics.collect {|v| v.updated_at}.max
        latest_activity_time ||= meet.created_at
        content.timestamp = latest_activity_time
        content.id = meet.id
        content.body = {}
        content.body[:encounter] = meet
        cirkle = cirkles0[meet.cirkle_id]
        if (cirkle && cirkle.meet_type == 6)
          # Only handle group cycle (solo and private cirkles are implicit
          # which only handle their chatters)
          content.body[:cirkle] = cirkle
        end
        contents << content
      }

      # New Topic/comments in cirkles, encounter topics are shown in
      # encounter's detail
      cirkles0.each_pair {|cirkle_id, cirkle|
        cirkle.loaded_topics.each {|topic|
          next unless cirkle.new_topic_ids.include?(topic.id)
          content = ContentAPI.new(:topic)
          content.timestamp = topic.updated_at
          content.id = topic.id
          content.body = {}
          content.body[:topic] = topic
          cirkle = cirkles0[cirkle_id]
          # Solo/Private cirkles not implicit cikles. Do not report back to client.
          # Instead, user user info.
          if cirkle.meet_type == 4 # solo cirkle
            content.body[:user] = @user
          elsif cirkle.meet_type == 5 # private cirkle
            friend = cirkle.loaded_users.select {|v| v.id != @user.id}.first
            friend ||= @user # unlikely, however force to solo mode
            content.body[:user] = friend
          else
            content.body[:cirkle] = cirkle
          end
          contents << content
        }
      }
    end

    # Keep the always-on-top contents on top.
    contents = contents.sort_by {|v| (current_time-v.timestamp)}
    # Filter by timestamp
    contents = contents.select {|content|
      is_between_time?(content.timestamp, after_time, before_time)
    }
    contents = contents.first(limit.to_i) if limit.present?
    # XXX, Currently, do not return top contents
    #contents = top_contents.concat(contents)
    attach_meet_infos_to_contents(contents)
    end

    self.class.benchmark("View") do
      respond_to do |format|
        format.html { }
        format.json { render :json => contents }
      end
    end
    end
  end

  # Chatters flat view
# def comments
#   assert_internal_error(@user)
#   assert_unauthorized(false, :except=>:html)
#   @chatters = @user.meets_chatters
#   respond_to do |format|
#     format.html {
#       @chatters = @chatters.paginate(:page => params[:page], :per_page => 25)
#       @title = @user.name_or_email
#     }
#     # JSON interface shall not come here
#     # Get all chatters is too costly, use meet detail instead.
#   end
# end

  def map
    inc = 50
    upto = params[:uptx] ? params[:uptx].to_i : inc
    @user = find_user(params[:id])
    assert_unauthorized(false, :except=>:html)
    @meet_type = params[:meet_type] ? params[:meet_type].to_i : nil
    meet_types = [@meet_type, @meet_type+3] if @meet_type
    with_user = admin_user? ? @user : current_user
    # Also get corresponding cirkles
    @meets = @user.top_meets_with(with_user, upto, meet_types)
    respond_to do |format|
      format.html {
        @total_count = @user.meets_with(with_user, meet_types).count
        attach_meet_infos(current_user, @meets)
        center_meet = @meets[0]
        @center_ll = center_meet.lat_lng if center_meet
        @center_ll = "37.387722,-121.966733" if @center_ll.blank?
        @title = @user.name_or_email
        # Calculate next upto, keep as-is if already exceed limit
        @more_upto = upto
        @more_upto += inc if upto < @total_count
      }
      # JSON interface shall use meets instead
    end
  end

# def following
#   @title = "Following"
#   @user = find_user(params[:id])
#   assert_unauthorized(@user)
#   @users = @user.following.paginate(:page => params[:page], :per_page => 25)
#   render 'show_follow'
# end
  
# def followers
#   @title = "Followers"
#   @user = find_user(params[:id])
#   assert_unauthorized(@user)
#   @users = @user.followers.paginate(:page => params[:page], :per_page => 25)
#   render 'show_follow'
# end

  def new
    @user  = User.new
    @title = "Sign up"
  end
  
  def create
    confirm_signup = !admin_user?
    confirm_signup = false # to make it simple, currently no confirmation required
    @filtered_params = {:email => @filtered_params[:email]} if confirm_signup
    @user = User.new(@filtered_params)
    pending_user = User.find_by_email(@user.email.strip.downcase)
    if (pending_user)
      if (pending_user.status == 2 || pending_user.status == 3)
        # If the user is already invitation or signup pending and now she try to signup
        # directly again, we shall let her go through without trigger email already
        # taken error.
        @user = pending_user
      elsif (pending_user.status == 1)
        # Free up the record of a deleted user if someone try to signup using it.
        pending_user.destroy
      end
    end
    saved = false
    @user.opt_lock_protected {
      if (confirm_signup)
        @user.temp_password = passcode if @user.temp_password.blank?
        @user.status = 2 # signup pending
        saved = @user.exclusive_save
      else # an admin user can signup an user without confirmation
        @user.status = 0 # sign it up
        saved = @user.save
      end
    }
    if saved
      if confirm_signup
        InvitationMailer.signup_confirmation(root_url, pending_user_url(@user), @user).deliver
      elsif !admin_user? 
        sign_in(@user)
      end
      respond_to do |format|
        format.html { redirect_to root_path, :flash => { :success => "Check your email for confirmation!" } }
        format.json { render :json => @user.to_json(JSON_USER_DETAIL_API) }
      end
    else
      @title = "Sign up"
      respond_to do |format|
        format.html { render 'new' }
        format.json { render :json => @user.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end
  
  def edit
    @title = "Edit user"
  end
  
  def update
    saved = false
    @user.opt_lock_protected {
      @user.status = 0
      @user.temp_password = nil # temp password is only one time use
      @filtered_params.delete("id") # interfere with update_attributes
      # If passwords are empty, do not update encrypt_password.
      if (@filtered_params["password"].blank? && @filtered_params["password_confirmation"].blank?)
        @filtered_params["password"] = User::NULL_PASSWORD;
        @filtered_params["password_confirmation"] = User::NULL_PASSWORD;
      end
      saved = @user.update_attributes(@filtered_params)
    }
    if saved
      # After password update, salt is changed, session becomes invalid.
      # Automatically re-signin after profile update
      re_sign_in(@user)
      respond_to do |format|
        format.html { redirect_back @user, :flash => { :success => "Profile updated!" } }
        format.json { render :json => @user.to_json(JSON_USER_DETAIL_API) }
      end
    else 
      respond_to do |format|
        format.html { @title = "Edit user"; render 'edit' }
        format.json { render :json => @user.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    assert_internal_error(@user)
    assert_unauthorized(false, :except=>:html)
    delete_user_associates
    @user.opt_lock_protected {
      @user.delete
      @user.exclusive_save
    }
    redirect_to users_path, :flash => { :success => "User removed!" }
  end

  def perm_destroy
    assert_internal_error(@user)
    assert_unauthorized(false, :except=>:html)
    @user.destroy
    redirect_to users_path, :flash => { :success => "User removed!" }
  end

  private

    @@score_categories = [100, 50, 25, 0]
    @@score_interval_in_months = 3
    @@score_ratios_by_interval = [100, 50, 25, 10, 5, 2, 1, 0]
    @@activity_weights = {:encounter=>1.0, :chatter=>0.2} # chatter currently not used
    def self.get_score_val(type, months_ago)
      interval_index = (months_ago/@@score_interval_in_months).floor
      interval_index = interval_index.at_most(@@score_ratios_by_interval.size-1)
      weight = @@activity_weights[type]
      weight ||= 1.0
      return @@score_ratios_by_interval[interval_index] * weight
    end
    def self.get_score_from_val(score_val)
      score = @@score_categories.find_index {|v| score_val > v}
      score = 1 if score == 0
      return score
    end
    # 1, 2, 3: 1 means closest
    def get_relation_score(activities)
      current_time = Time.now.getutc
      score_val = 0
      activities.each {|activity|
        activity_type, activity_time = *activity
        months_ago = current_time.month - activity_time.month
        score_val += UsersController.get_score_val(activity_type, months_ago)
      }
      score = UsersController.get_score_from_val(score_val)
      return [current_time, score]
    end
    def get_stats_for_friend(friend, cirkles0, encounters0)
      encounter_count = encounters0.size
      last_time = encounters0.present? ? encounters0.first.time : nil
      activities = encounters0.collect {|v| [:encounter, v.time]}
      # The cirkles0 hold all direct chatters, but right now they are not used to 
      # calculate relation score.
      score = get_relation_score(activities)
      return {:encounter_count=>encounter_count, :last_encounter_time=>last_time,
              :relation_score=>score}
    end
    def get_friends_stats(friends, loaded_meets)
      return {} if friends.blank?
      friends_meets = @user.friends_meets(nil, loaded_meets, [:id,:time,:meet_type,:lat,:lng],
                                          friends, self, true)
      friends_stats = {}
      friends_meets.each_pair {|friend, meets0|
        encounters0 = meets0.select {|v| v.is_encounter?}
        cirkles0 = meets0.select {|v| v.is_cirkle? && v.meet_type == 5 }
        friends_stats[friend] = get_stats_for_friend(friend, cirkles0, encounters0)
      }
      return friends_stats
    end

    def get_stats_for_cirkle(cirkle, encounters0)
      encounter_count = encounters0.size
      last_time = encounters0.present? ? encounters0.first.time : nil
      first_encounter = encounters0.present? ? encounters0.last : nil
      activities = encounters0.collect {|v| [:encounter, v.time]}
      score = get_relation_score(activities)
      return {:encounter_count=>encounter_count, :last_encounter_time=>last_time,
              :first_encounter=>first_encounter, :relation_score=>score}
    end
    def get_cirkles_stats(cirkles, loaded_meets)
      return {} if cirkles.blank?
      # Avoid duplicated meet load
      cirkle_ids = cirkles.collect {|v| v.id}.to_set
      cirkles_meet_ids = Meet.select([:id,:time])
                             .where("cirkle_id IN (?)", cirkle_ids).select {|v| v.id}.uniq
      loaded_meets = loaded_meets.select {|v| cirkle_ids.include?(v.cirkle_id)}
      loaded_meet_ids = loaded_meets.collect {|v| v.id}.to_set
      missing_meet_ids = cirkles_meet_ids.select {|v| !loaded_meet_ids.include?(v)}
      missing_meets = []
      if missing_meet_ids.present?
        missing_meets = Meet.select([:id,:time,:meet_type,:cirkle_id,:lat,:lng])
                            .where('id IN (?)', missing_meet_ids)
      end
      cirkles_encounters = {}
      missing_meets.concat(loaded_meets).each {|meet|
        next unless meet.is_encounter?
        cirkle = cirkles.select {|v| v && v.id == meet.cirkle_id}.first
        (cirkles_encounters[cirkle] ||= Array.new) << meet
      }
      cirkles_stats = {}
      cirkles_encounters.each {|v|
        cirkle = v[0]
        encounters0 = v[1].select {|x| x.is_encounter?}
        cirkles_stats[cirkle] = get_stats_for_cirkle(cirkle, encounters0)
      }
      return cirkles_stats
    end

    def get_activities_summary(summary_limit, meets0, photos)
      activities_summary = []
      meets0.first(summary_limit).each {|meet|
        next unless meet.is_encounter? # only handle true encounter events
        summary = ContentAPI.new(:encounter)
        summary.timestamp = meet.created_at
        summary.id = meet.id
        summary.body = {:encounter_summary=>meet}
        activities_summary << summary
      }
      meets0.each {|meet| photos.select {|v| v.meet_id == meet.id}.each {|photo|
        summary = ContentAPI.new(:photo)
        summary.timestamp = photo.created_at
        summary.id = photo.id
        summary.body = {:photo=>photo}
        activities_summary << summary
      }}
      return activities_summary.sort_by {|v| v.timestamp}.reverse.first(summary_limit)
    end

    def attach_meet_infos(user, meets, has_pending=false)
      attach_meet_mviews(user, meets)
      attach_meet_top_users(meets)
      attach_meet_top_chatters(meets)
      attach_meet_invitations(user, meets) if (has_pending)
    end

    def attach_meet_mviews(user, meets)
      mviews = Mview.user_meets_mview(user, meets).to_a
      meets.each {|meet|
        meet.meet_mview = mviews.select {|mview| mview.meet_id == meet.id}.first
        meet.hoster_mview = Mview.user_meet_mview(meet.hoster, meet).first if meet.has_hoster?
      }
    end

    def attach_meet_top_users(meets)
      user_ids = Set.new
      meets.each {|meet| user_ids.merge(meet.top_user_ids)}
      users = find_users(user_ids.to_a).compact
      meets.each {|meet|
        meet.loaded_top_users = meet.top_user_ids.collect {|id| users.find {|v| v.id == id}}
      }
    end

    def attach_meet_top_chatters(meets)
      chatter_ids = Set.new
      meets.each {|meet| chatter_ids.merge(meet.top_topic_ids)}
      chatters = find_chatters(chatter_ids.to_a).compact
      user_ids = Set.new
      chatters.each {|chatter| user_ids << chatter.user_id}
      users = find_users(user_ids.to_a).compact
      chatters.each {|chatter| chatter.loaded_user = find_user(chatter.user_id)}
      meets.each {|meet|
        meet.loaded_top_chatters =
          meet.top_topic_ids.collect {|id| chatters.drop_while {|ch| ch.id != id}.first}.compact
      }
    end

    def attach_meet_invitations(user, meets)
      pending_invitations = user.pending_invitations.to_a
      meets.each {|meet|
        # invitations are sorted by created_at time. Hope it still keep the timed
        # order after the select procedure, so the first is the latest one,
        meet.meet_invitations = pending_invitations.select {|invitation|
          invitation.meet_id == meet.id
        }
      }
    end

    def delete_user_associates
      delete_mposts(@user.mposts)
      #delete_mviews(@user.mviews)
      delete_chatters(@user.chatters)
      delete_invitations(@user.invitations)
    end

    def get_meets_from_content(content, content_meets)
      if content.class == ContentAPI
        get_meets_from_content(content.body, content_meets)
      elsif content.class == Meet
        content_meets << content
      elsif content.class == Array
        content.each {|v| get_meets_from_content(v, content_meets)}
      elsif content.class == Hash
        content.each_pair {|k, v| get_meets_from_content(v, content_meets)}
      end
    end
    def get_chatters_from_content(content, content_chatters)
      if content.class == ContentAPI
        get_chatters_from_content(content.body, content_chatters)
      elsif content.class == Chatter
        content_chatters << content
      elsif content.class == Array
        content.each {|v| get_chatters_from_content(v, content_chatters)}
      elsif content.class == Hash
        content.each_pair {|k, v| get_chatters_from_content(v, content_chatters)}
      end
    end
    def attach_meet_infos_to_contents(contents, has_pending=false)
      return if contents.empty?
      content_meets = Set.new
      get_meets_from_content(contents, content_meets)
      content_meets = content_meets.to_a
      has_pending = content_meets.any? {|v| v.is_pending}
      attach_meet_infos(@user, content_meets, has_pending)
      content_meets.each {|meet|
        #meet.friends_name_list_params = {:except=>current_user,:delimiter=>", ",:max_length=>80}
        meet.friends_name_list_params = {:except=>nil,:delimiter=>", ",:max_length=>40}
      }
      content_chatters = Set.new
      get_chatters_from_content(contents, content_chatters)
      user_ids = Set.new
      content_chatters.each {|chatter| user_ids << chatter.user_id}
      users = find_users(user_ids.to_a).compact
      content_chatters.each {|chatter| chatter.loaded_user = find_user(chatter.user_id)}
    end

    def is_between_time?(time, after_time, before_time)
      return (after_time.blank? || time >= after_time) &&
             (before_time.blank? || time <= before_time)
    end
    def get_pending_meets(user, cirkle=nil) 
      pending_meets0 = user.pending_meets.where("meets.meet_type = ?", 3)
      pending_meets0 = pending_meets0.where("meets.cirkle_id = ?", cirkle.id) if cirkle
      return @user.true_pending_meets(pending_meets0)
    end
    def get_cirkles_meets(meets0)
      cirkles_meets = {}
      meets0.each {|meet|
        if meet.is_encounter?
          cirkle = meets0.select {|v| v.id == meet.cirkle_id}.first
        else # also include cirkle itself as part of meets
          cirkle = meet
        end
       (cirkles_meets[cirkle] ||= Array.new) << meet if cirkle
      }
      return cirkles_meets
    end
    # Load and attach meet users and chatters
    def attach_meet_details(user, meets0, cirkles0, encounters0, before_time, after_time)
      meet_ids = meets0.collect {|v| v.id}.to_set
      meets0 = meets0.index_by(&:id)
      mposts0 = Mpost.select([:user_id,:meet_id,:created_at])
                     .where("meet_id IN (?) AND status = ?", meet_ids, 0)
      chatters0 = Chatter.where("meet_id IN (?)", meet_ids)
      user_ids = mposts0.collect {|v| v.user_id}.concat(chatters0 .collect {|v| v.user_id}).uniq.compact
      users0 = find_users(user_ids).index_by(&:id)

      meets_mposts = {}
      mposts0.each {|mpost|
        meet = meets0[mpost.meet_id]
        (meets_mposts[meet] ||= Array.new) << mpost
      }
      meets_mposts.each_pair {|meet, meet_mposts|
        meet.loaded_users = meet_mposts.collect {|v| users0[v.user_id]}.uniq.compact
        meet.is_new_encounter = meet.is_encounter? &&
                                ((!after_time && !before_time) ||
                                 is_between_time?(meet.created_at, after_time, before_time))
        new_user_ids = Set.new
        if meet.is_new_encounter # marked new users for new encounters/new cirkles
          if meet.is_cirkle?
            new_user_ids = meet_mposts.select {|v|
                             (!after_time && !before_time) &&
                             is_between_time?(v.created_at, after_time, before_time)
                           }.collect {|v| v.user_id}.compact.to_set
          elsif meet.cirkle_id
            meet_mposts.each {|meet_mpost|
              next unless meet_mpost.user_id
              cirkle_mposts = mposts0.select {|v| v.meet_id == meet.cirkle_id && v.user_id == meet_mpost.user_id}
              # The user is new if its correspondent cirkle mpost is created after her encounter's mpost
              new_user_ids << meet_mpost.user_id if (cirkle_mposts.all? {|v| meet_mpost.created_at <= v.created_at})
            }
          end
        end
        meet.new_user_ids = new_user_ids
        meet.loaded_topics = []
        meet.new_topic_ids = Set.new
      }
      cache_chatters(chatters0)
      chatters0 = chatters0.group_by(&:meet_id)
      chatters0.each_pair {|meet_id, meet_chatters|
        meet = meets0[meet_id]
        meet_chatters.each {|chatter| chatter.loaded_user = users0[chatter.user_id]}
        meet_topics = meet_chatters.select {|v| v.topic?}.index_by(&:id)
        meet_chatters = meet_chatters.group_by(&:topic_id)
        meet_chatters.each_pair {|topic_id, topic_chatters|
          new_chatters = topic_chatters.select {|v|
                           is_between_time?(v.updated_at, after_time, before_time)
                         }
          if topic_id.nil?
            meet.loaded_topics = topic_chatters
            meet.new_topic_ids = new_chatters.collect {|v| v.id}.to_set
          else
            topic = meet_topics[topic_id] 
            topic.loaded_comments = topic_chatters
            topic.new_comment_ids = new_chatters.collect {|v| v.id}.to_set
          end
        }
      }
    end

end
