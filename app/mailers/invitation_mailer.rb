class InvitationMailer < ActionMailer::Base

  def signup_invitation (user)
    recipients "#{user.name} <#{user.email}>"
    from      "no-reply@kaya-labs.com"
    subject   "You are invited to a Kaya Meet!"
    sent_on   Time.now
    body      {:user => user, :url => "http://www.kayameet.com"}
  end

end
