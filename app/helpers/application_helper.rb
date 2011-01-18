module ApplicationHelper
  
  # Return a title on a per-page basis.
  def title
    base_title = "Kaya Mobile App"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
  
  def logo
    image_tag("kaya-logo-2-blueletter-on-white-3.jpg", :alt => "Kaya Mobile App", :class => "round")
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
    session[:return_to] = request.request_uri
    #session[:return_to] = request.fullpath
  end

  # Redirects to the session[:return_to] uri if there is one and to the given block of params if not
  def redirect_back(*params)
    url = session[:return_to]
    session[:return_to] = nil
    default_url ||= params.shift
    except_url = params.delete(:except_url)
    if (url.blank? || (excpet_url && match_url?(url, url_for(except_url))))
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
    options[:class] || = ""; options[:class] += " reset"
    form.submit(button.to_s, options.merge(:type => "button", :name => name.to_a,
                :onclick => (remote ?  "this.form.reset()" : "this.form.reset().submit()")))
    #return submit(button.to_s, options.merge(:type => "reset", :name => name.to_a))
    #return form.submit(button.to_s, options.merge(:name => name.to_a))
    #return link_to(button.to_s, ".", options)
  end
  
end
