module MeetsHelper
  def link_to_meet_image(meet, pending=false)
   return pending ? link_to(image_tag(meet.image_url_or_default), "##",
                            :title => "Confirm first to access meet detail") :
                    link_to_unless_current(image_tag(meet.image_url_or_default), meet,
                            :title => "Meet detail")
  end

  def link_to_meet_detail(meet)
    return current_page?(meet) ?  "".html_safe :
                  link_to_unless_current("detail ...", meet, :title => "Meet detail")
  end

  def link_to_meet_detail_arrow(meet)
    return link_to_unless_current(image_tag("blue_arrow.jpg"), meet, :title => "Meet detail")
  end

  def link_to_meet_name(meet, show_not_named=false, pending=false)
    name = meet.meet_name
    return name.blank? ? (show_not_named ? "Not named yet".html_safe : "".html_safe) :
           pending ?  link_to(name, "##", :title => "Confirm first to access meet detail") :
                      link_to_unless_current(name, meet, :title => "Meet Detail")
  end

  def link_to_meet_address(meet, pending=false)
    address = meet.meet_address_or_ll
    return address.blank? ? "".html_safe :
           meet.lat_lng.blank? ? address.html_safe :
           pending ? link_to(address, "##", :title => "Confirm first to access meet map") :
                     link_to_unless_current(address, map_meet_path(meet),
                                    :title => "Larger map: #{meet.meet_location_or_ll}")
  end

  def link_to_meet_time(meet, pending=false)
    # ZZZ hong.zhao, use meet zone time or user local zone time? No of them is implemented yet.
    zone_time = meet.meet_time.in_time_zone(meet.time_zone)
    time = zone_time.strftime("%Y-%m-%d %I:%M%p")
    return pending ? link_to("#{time_ago_in_words(meet.meet_time)} ago", "##",
                             :title => "Confirm first to access meet detail") :
                     link_to_unless_current("#{time_ago_in_words(meet.meet_time)} ago", meet,
                             :title => "Meet detail: #{time}")
  end

  def link_to_meet_description(meet, show_link=false, pending=false)
    description = meet.meet_description
    return "".html_safe if description.blank?
    return !show_link ? descritpion.html_safe :
           pending ? link_to(description, "##", :title => "Confirm first to access meet detail") :
                     link_to_unless_current(description, meet, :title => "Meet detail")
  end

  def link_to_meet_static_map(meet, pending=false)
    #return "".html.safe if current_page?(map_meet_path(meet))
    map_url = meet.static_map_url(140, 80, 15, "mid")
    return map_url.blank? ? "".html_safe :
           pending ? link_to(image_tag(map_url), "##", :title => "Confirm first to access meet map") :
                     link_to_unless_current(image_tag(map_url), map_meet_path(meet),
                                   :title => "Larger map: #{meet.meet_location_or_ll}")
  end

  def link_to_meet_static_map_small(meet, pending=false)
    #return "".html_safe if current_page?(map_meet_path(meet))
    map_url = meet.static_map_url(100, 60, 14, "small")
    return map_url.blank? ? "".html_safe :
           pending ? link_to(image_tag(map_url), "##", :title => "Confirm first to access meet map") :
                      link_to_unless_current(image_tag(map_url), map_meet_path(meet),
                                   :title => "Larger map: #{meet.meet_location_or_ll}")
  end

  def link_to_meet_friends(meet, pending=false)
    friends, friends_name, more = *meet.friends_name_list(current_user, ", ", 25)
    html = "".html_safe
    friends.each {|friend|
      html += ", " unless friend == friends.first
      html += %Q{
        <span class="user_name"> #{link_to_user_name(friend, true, pending)} </span>
      }.html_safe
    }
    if more > 0
      html += " and "
      html += pending ? link_to("#{more} more friends", "##",
                                :title => "Confirm first to access friends list") :
                        link_to_unless_current("#{more} more friends", meet,
                                :title => "All friends of this meet")
    end
    if (!pending && !html.present? && !current_page?(new_meet_invitation_path(meet)))
      return link_to_unless_current("add friends ...", new_meet_invitation_path(meet),
                                    :title => "Add friends to this meet")
    end
    return html
  end

  def link_to_meet_friends_short(meet, pending=false)
    if meet.friends_count > 0
      html = "Met with ".html_safe
      html += pending ? link_to("#{more} more friends", "##", 
                                :title => "Confirm first to access friends list") :
                        link_to_unless_current("#{meet.friends_count} friends", meet,
                                     :title => "All friends of this meet")
      return html
    else
      return (!pending && !current_page?(new_meet_invitation_path(meet))) ? 
               link_to_unless_current("add friends ...", new_meet_invitation_path(meet),
                                      :title => "Add friends to this meet") : "".html_safe
    end
  end

  def meets_user_path_of_type(user, meet_type)
    return meets_user_path(user)+params_url(:meet_type=>meet_type)
  end
  def map_user_path_of_type(user, meet_type)
    return map_user_path(user)+params_url(:meet_type=>meet_type)
  end

  def meet_chatters_count(meet)
    return %Q{
      T# #{meet.topics_count}
      C# #{meet.chatters_count}
      P# #{meet.photos_count}
    }.html_safe
  end

  def latest_chatters_brief(meet)
    html = "".html_safe
    #latest_chatters = meet.latest_chatters.to_a
    latest_chatters = meet.loaded_top_chatters
    latest_chatters.each {|chatter|
      if chatter.content.present?
        content = truncate(chatter.content, :length => 50, :separator => ' ')
        html += %Q{
          <li class=chatter_content>
            <span class="user_name"> #{link_to_user_name chatter.user} </span>
            <span class="chatter_content_body"> #{content} </span>
          </li>}.html_safe
        break if html.size > 50
      end
    }
    return html
  end

  def meet_summary_pending(meet)
    return %Q{
      <td class="meet_avatar">
        #{link_to_meet_image meet, true}
      </td>
      <td class="meet_summary_body">
      <ul>
        <li class="meet_name">
          #{meet.meet_name.present? ? link_to_meet_name(meet, false, true) : ""}
        </li>
        <li class="meet_description">
          #{false && meet.meet_description.present? ? link_to_meet_description(meet, true) : ""}
        </li>
        <li class="meet_friends">
          #{link_to_meet_friends meet, true}
        </li>
        <li class="meet_time">
          #{link_to_meet_time meet, true}
        </li>
        <li class="meet_hoster">
          #{meet.has_hoster? ? ("Hosted by "+link_to_user_name(meet.hoster, true, true)) : ""}
        </li>
        <li class="meet_address">
          #{link_to_meet_address meet, true}
        </li>
        <li class="meet_statistics">
          #{meet_chatters_count(meet)}
        </li>
      <ul>
      </td>
    }.html_safe
  end

  def meet_summary_list(meet)
    return %Q{
      <td class="meet_avatar">
        #{link_to_meet_image meet}
      </td>
      <td class="meet_summary_body">
      <ul>
        <li class="meet_name">
          #{meet.meet_name.present? ? link_to_meet_name(meet) : ""}
        </li>
        <li class="meet_description">
          #{false && meet.meet_description.present? ? link_to_meet_description(meet) : ""}
        </li>
        <li class="meet_friends">
          #{link_to_meet_friends meet}
        </li>
        <li class="meet_time">
          #{link_to_meet_time meet}
        </li>
        <li class="meet_hoster">
          #{meet.has_hoster? ? ("Hosted by "+link_to_user_name(meet.hoster)) : ""}
        </li>
        <li class="meet_address">
          #{meet.meet_address_or_ll}
        </li>
        <li class="meet_statistics">
          #{meet_chatters_count(meet)}
        </li>
      <ul>
      </td>
    }.html_safe
  end

  def meet_summary_brief(meet)
    return %Q{
      <div class="meet_avatar">
        #{link_to_meet_image meet}
      </div>
      <div class="meet_summary_body">
      <ul>
        <li class="meet_name">
          #{meet.meet_name.present? ? link_to_meet_name(meet) : ""}
        </li>
        <li class="meet_description">
          #{false && meet.meet_description.present? ? link_to_meet_description(meet) : ""}
        </li>
        <li class="meet_friends_short">
          #{link_to_meet_friends_short meet}
        </li>
        <li class="meet_time">
          #{link_to_meet_time meet}
        </li>
        <li class="meet_hoster">
          #{meet.has_hoster? ? ("Hosted by "+link_to_user_name(meet.hoster)) : ""}
        </li>
        <li class="meet_address">
          #{meet.meet_address_or_ll}
        </li>
        <li class="meet_statistics">
          #{meet_chatters_count(meet)}
        </li>
      <ul>
      </div>
    }.html_safe
  end

  def meet_marker(meet)
    return %Q{
      <div class="meet_summary_marker">
        #{meet_summary_brief(meet)}
      </div>
    }.gsub(/\n/, "\\n").html_safe
  end
end
