
class InvitationMailer < ActionMailer::Base

  default :from => "noreply@kaya-labs.com",
          :bcc => "test.kaya@kaya-labs.com"
   
  def signup_invitation(root_url, url, user, invitee, message, meet)
    @root_url, @url = root_url, url
    @user, @invitee, @message, @password, @meet = user, invitee, message, invitee.temp_password, meet
    mail(#:cc => user.email, 
         :to => invitee.email,
         :subject => "You've been invited to a Kaya Meet")
  end

  # Use already signup, link to pending confirmation 
  def meet_invitation(root_url, url, user, invitee, message, meet)
    @root_url, @url = root_url, url
    @user, @invitee, @message, @meet = user, invitee, message, meet
    mail(#:cc => user.email, 
         :to => invitee.email,
         :subject => "You've been added to a Kaya Meet")
  end

  def signup_confirmation(root_url, url, user)
    @root_url, @url = root_url, url
    @user, @password = user, user.temp_password
    mail(:to => user.email,
         :subject => "Kaya Meet confirmation")
  end

  def password_reset(root_url, url, user)
    @root_url, @url = root_url, url
    @user, @password = user, user.temp_password
    mail(:to => user.email,
         :subject => "Kaya Meet password reset")
  end

#  def signup_invitation (user)
#    recipients "#{user.name} <#{user.email}>"
#    from      "no-reply@kaya-labs.com"
#    subject   "You are invited to a Kaya Meet!"
#    sent_on   Time.now
#    body      {:user => user, :url => "http://www.kayameet.com"}
#  end

end
