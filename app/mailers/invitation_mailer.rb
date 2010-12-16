
class InvitationMailer < ActionMailer::Base

  default :from => "notifications@example.com"
   
  def signup_invitation(user)
    @user = user
    @url  = "http://www.kayameet.com"
    mail(:to => user.email,
         :bcc => "wenjing.chu@kaya-labs.com",
        :subject => "You've been invited to a Kaya Meet")
  end
#  def signup_invitation (user)
#    recipients "#{user.name} <#{user.email}>"
#    from      "no-reply@kaya-labs.com"
#    subject   "You are invited to a Kaya Meet!"
#    sent_on   Time.now
#    body      {:user => user, :url => "http://www.kayameet.com"}
#  end

end
