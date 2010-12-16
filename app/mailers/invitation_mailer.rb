class InvitationMailer < ActionMailer::Base
  default :from => "no-reply@kaya-labs.com"

  def signup_invitation (user)
    @user = user
    @url = "http://www.kayameet.com"
    mail (:to => user.email,
          :bcc => "wenjing.chu@kaya-labs.com",
          :subject => "You've been invited to a Kaya Meet")
  end

end
