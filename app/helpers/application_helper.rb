module ApplicationHelper
  
  # Return a title on a per-page basis.
  def title
    base_title = "Kaya Meet"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
     image_tag("logo_04.png", :alt => "Kaya Meet")
  end

  def invalid_url
    return root_url+"404.html"
  end
  def unauthorized_url
    return root_url+"422.html"
  end
  def removed_url
    return root_url+"422removed.html"
  end
  def internal_error_url
    return root_url+"500.html"
  end
  def invalid_path
    return root_path+"404.html"
  end
  def unauthorized_path
    return root_path+"422.html"
  end
  def removed_path
    return root_path+"422removed.html"
  end
  def internal_error_path
    return root_path+"500.html"
  end

  def params_url(args)
    url = ""
    args.each {|key, val|
      if val.present?
        url += (url=="" ? "?" : "&") + "#{key.to_s}=#{val.to_s}"
      end
    }
    return url
  end

  # Save an action's uri in the session so it can be used to return to
  # Use a before_filter to run this on actions which will be redirected back to later on
  def store_return_point
    #session[:return_to] = request.request_uri
    session[:return_to] = request.fullpath
  end
  def clear_return_point
    session[:return_to] = nil;
  end

  # Redirects to the session[:return_to] uri if there is one and to the given block of params if not
  def redirect_back(*params)
    url = session[:return_to]
    clear_return_point
    default_url ||= params.shift
    except_url = params.delete(:except_url)
    if (url.blank? || (except_url && match_url?(url, url_for(except_url))))
      url = default_url
    end
    redirect_to(url, *params)
  end

  # Redirect somewhere that will eventually return back to here
  def redirect_away(*params)
    store_return_point
    redirect_to(*params)
  end

  def link_back(text, *params)
    session[:return_to] ? link_to(text, session[:return_to]) : link_to(text, *params)
  end

  def match_url?(url1, url2)
    return (/^#{url1}/ =~ url2) || (/^#{url2}/ =~ url1)
  end

  def form_cancel_button(form, button, name, options={})
    remote = options.delete(:remote)
    remote = true if remote.nil?
    options[:class] ||= "";
    options[:class] += " reset" if remote
    form.submit(button.to_s,
                options.merge(:type => remote ? "button" : "submit", :name => name.to_s)
                       .merge(remote ? {:onclick => "this.form.reset()"} : {}))
    #return submit(button.to_s, options.merge(:type => "reset", :name => name.to_a))
    #return form.submit(button.to_s, options.merge(:name => name.to_a))
    #return link_to(button.to_s, ".", options)
  end

  def width_holder(size=100)
    return %Q{
      <div style="visibility:hidden;height:0px">
        #{'1 '*50}
      </div>
    }.html_safe
  end
  def height_holder(height)
    return %Q{
      <div style="width:1px;min-height:#{height}px;position:relative;margin-left:-10000px;float:left">
      </div>
    }.html_safe
  end
  
  def find_user(user_id)
    return nil if user_id.blank?
    user_id = user_id.to_i
    @user_cache ||= {}
    user = @user_cache[user_id]
    if !user
      user = User.find_by_id(user_id)
      @user_cache[user.id] = user if user
    end
    return user
  end
  def find_users(user_ids)
    return [] if user_ids.blank?
    user_ids = user_ids.collect {|v| v.to_i}
    @user_cache ||= {}
    missing_user_ids = user_ids.select {|v| !@user_cache.include?(v)}
    if !missing_user_ids.empty?
      missing_users = User.find(missing_user_ids).compact
      missing_users.each {|user| @user_cache[user.id] = user}
    end
    return user_ids.collect {|id| @user_cache[id]}
  end

  def find_mpost(mpost_id)
    return nil if mpost_id.blank?
    mpost_id = mpost_id.to_i
    @mpost_cache ||= {}
    mpost = @mpost_cache[mpost_id]
    if !mpost
      mpost = Mpost.find_by_id(mpost_id)
      @mpost_cache[mpost.id] = mpost if mpost
    end
    return mpost
  end
  def find_mposts(mpost_ids)
    return [] if mpost_ids.blank?
    mpost_ids = mpost_ids.collect {|v| v.to_i}
    @mpost_cache ||= {}
    missing_mpost_ids = mpost_ids.select {|v| !@mpost_cache.include?(v)}
    if !missing_mpost_ids.empty?
      missing_mposts = Mpost.find(missing_mpost_ids).compact
      missing_mposts.each {|mpost| @mpost_cache[mpost.id] = mpost}
    end
    return mpost_ids.collect {|id| @mpost_cache[id]}
  end

  def find_meet(meet_id)
    return nil if meet_id.blank?
    meet_id = meet_id.to_i
    @meet_cache ||= {}
    meet = @meet_cache[meet_id]
    if !meet
      meet = Meet.find_by_id(meet_id)
      @meet_cache[meet.id] = meet if meet
    end
    return meet
  end
  def find_meets(meet_ids)
    return [] if meet_ids.blank?
    meet_ids = meet_ids.collect {|v| v.to_i}
    @meet_cache ||= {}
    missing_meet_ids = meet_ids.select {|v| !@meet_cache.include?(v)}
    if !missing_meet_ids.empty?
      missing_meets = Meet.find(missing_meet_ids).compact
      missing_meets.each {|meet| @meet_cache[meet.id] = meet}
    end
    return meet_ids.collect {|id| @meet_cache[id]}
  end

  def find_chatter(chatter_id)
    return nil if chatter_id.blank?
    chatter_id = chatter_id.to_i
    @mpost_cache ||= {}
    @chatter_cache ||= {}
    chatter = @chatter_cache[chatter_id]
    if !chatter
      chatter = Chatter.find_by_id(chatter_id)
      @chatter_cache[chatter.id] = chatter if chatter
    end
    return chatter
  end
  def find_chatters(chatter_ids)
    return [] if chatter_ids.blank?
    @chatter_cache ||= {}
    chatter_ids = chatter_ids.collect {|v| v.to_i}
    missing_chatter_ids = chatter_ids.select {|v| !@chatter_cache.include?(v)}
    if !missing_chatter_ids.empty?
      missing_chatters = Chatter.find(missing_chatter_ids).compact
      missing_chatters.each {|chatter| @chatter_cache[chatter.id] = chatter}
    end
    return chatter_ids.collect {|id| @chatter_cache[id]}
  end

  def cache_users(users)
    @user_cache ||= {}
    users.each {|user|
      @user_cache[user.id] ||= user
    }
  end
  def cache_mposts(mposts)
    @mpost_cache ||= {}
    mposts.each {|mpost|
      @mpost_cache[mpost.id] ||= mpost
    }
  end
  def cache_meets(meets)
    @meet_cache ||= {}
    meets.each {|meet|
      @meet_cache[meet.id] ||= meet
    }
  end
  def cache_chatters(chatters)
    @chatter_cache ||= {}
    chatters.each {|chatter|
      @chatter_cache[chatter.id] ||= chatter
    }
  end

end
