
class InvitationMailer < ActionMailer::Base

  default :from => "your_kaya@kaya-labs.com"
   
  def signup_invitation(user, invitee)
    @user = user
    @url  = "http://www.kayameet.com"
    mail(:cc => user.email,
         :to => invitee,
         :bcc => "test.kaya@kaya-labs.com",
#        :bcc => (Rails.env.production? ? "test.kaya@kaya-labs.com" :
#                                         ENV["KAYAMEET_MAILER_BCC"]),
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
