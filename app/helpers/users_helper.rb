module UsersHelper
# def gravatar_for(user, options = { :size => 50 })
#   gravatar_image_tag(user.email.downcase, :alt => user.name,
#                                           :class => 'gravatar',
#                                           :gravatar => options)
# end

  def link_to_user_detail_arrow(user)
    return link_to_unless_current(image_tag("blue_arrow.jpg"),
                                  current_user?(user) ? user_path(user) : meets_user_path(user),
                                  :title => current_user?(user) ?
                                      user.name_or_email : "Meets with #{user.name_or_email}")
  end

  def link_to_user_image(user)
    if user.blank?
      return image_tag(User.default_photo)
    elsif user.user_avatar.present?
      return link_to_unless_current(image_tag(user.user_avatar),
                                    current_user?(user) ? user_path(user) : meets_user_path(user),
                                    :title => current_user?(user) ?
                                        user.name_or_email : "Meets with #{user.name_or_email}")
    else
      return "".html_safe
    end
  end

  def link_to_user_image_small(user)
    if user.blank?
      return image_tag(User.default_photo_small)
    elsif user.user_avatar_small.present?
      return link_to_unless_current(image_tag(user.user_avatar_small),
                                    current_user?(user) ? user_path(user) : meets_user_path(user),
                                    :title => current_user?(user) ?
                                        user.name_or_email : "Meets with #{user.name_or_email}")
    else
      return "".html_safe
    end
  end

  def link_to_user_name(user, current_you=false, pending=false)
    if (current_user?(user) && current_you)
      return "You".html_safe
    elsif user.blank?
      return "Anonymous".html_safe
    elsif current_user?(user)
      return link_to_unless_current(user.name_or_email, user_path(user), :title => user.name_or_email)
    else
      return pending ? link_to(user.name_or_email, "##",
                               :title => "Confirm first to access meets with list") :
                       link_to_unless_current(user.name_or_email, meets_user_path(user),
                               :title => "Meets with #{user.name_or_email}")
    end
  end

  def link_to_user_meets_text(user, text)
    return link_to_unless_current(text, meets_user_path(user),
                                  :title => current_user?(user) ?
                                      "All meets" : "All meets with #{user.name_or_email}")
  end

  def link_to_user_friends_text(user, text)
    return link_to_unless_current(text, friends_user_path(user), :title => "All friends")
  end

  def map_user_path_upto(user, meet_type, upto)
    return "#{map_user_path_of_type(user, meet_type)}&uptx=#{upto}"
  end

  def link_to_pending_meet_count(user)
    count = user.true_pending_meets.count
    return count > 0 ?
            link_to_unless_current("You have #{count} meet invitations", pending_meets_user_path(user),
                                    :title => "All pending meet invitations",
                                    :class => "link_button") : "".html_safe
  end

end
