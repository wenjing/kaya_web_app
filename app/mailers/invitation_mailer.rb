class InvitationMailer < ActionMailer::Base
  default :from => "no-reply@kaya-labs.com"

  def signup_invitation (user, recipients)
    @user = user
    @recipients = recipients
    @url = "www.kayameet.com"
    mail (:to => @recipients,
          :bcc => "wenjing.chu@kaya-labs.com",
          :subject => "You've been invited to a Kaya Meet")
  end

end
