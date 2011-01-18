
class InvitationMailer < ActionMailer::Base

  default :from => "noreply@kaya-labs.com"
  #root_url = "http://www.kayameet.com"
   
  # Use is pending, link to root to signup.
  # ZZZ hong.zhao, shall carry user email and meet_id so that
  # it will lead user to meet detail upon signup.
  def signup_invitation(user, invitee, message, meet)
    url = pending_user_path(invitee)
    mail(#:cc => user.email, 
         :to => invitee.email,
         :bcc => "test.kaya@kaya-labs.com",
         :subject => "You've been invited to a Kaya Meet",
         :body => {:user => user, :root_url => root_path, :url => url,
                   :message => message, :password => invitee.temp_password})
  end

  # Use already signup, link to pending confirmation 
  def meet_invitation(user, invitee, message, meet)
    url = meet ? user_pending_meets_path(meet) : root_path
    mail(#:cc => user.email, 
         :to => invitee.email,
         :bcc => "test.kaya@kaya-labs.com",
         :subject => "You've been added to a Kaya Meet",
         :body => {:user => user, :root_url => root_path, :url => url,
                   :message => message})
  end

  def signup_confirmation(user)
    url = pending_user_path(user)
    mail(:to => user.email,
         :bcc => "test.kaya@kaya-labs.com",
         :subject => "Kaya Meet confirmation",
         :body => {:root_url => root_path, :url => url,
                   :password => invitee.temp_password})
  end

  def password_reset(user)
    url = pending_user_path(user)
    mail(:to => user.email,
         :bcc => "test.kaya@kaya-labs.com",
         :subject => "Kaya Meet password reset",
         :body => {:root_url => root_path, :url => url,
                   :password => invitee.temp_password})
  end

#  def signup_invitation (user)
#    recipients "#{user.name} <#{user.email}>"
#    from      "no-reply@kaya-labs.com"
#    subject   "You are invited to a Kaya Meet!"
#    sent_on   Time.now
#    body      {:user => user, :url => "http://www.kayameet.com"}
#  end

end
