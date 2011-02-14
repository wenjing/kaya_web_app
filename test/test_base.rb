$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'

require 'active_support/core_ext'
require 'kaya_base'
require 'faker'

class TestBase
  cattr_accessor :root_url
  #@@root_url = "http://localhost:3000/"
  @@root_url = "http://kayameet.com/"
  @@rest_options = {:open_timeout=>600, :timeout=>600}
  def self.rc_resource(url, user)
    options = user ? @@rest_options.merge(user.credential) : @@rest_options
    return RestClient::Resource.new(@@root_url+url, options)
  end
  def self.destroy_all(marker) # destroy all records carrying the marker
    User.all.each {|user|
      user.destroy if marker =~ user.email
    }
    Chatter.all.each {|chatter|
      chatter.destroy if marker =~ chatter.content
    }
    Mview.all.each {|mview|
      mview.destroy if marker =~ mview.name || marker =~ mview.location
    }
    Mpost.all.each {|mpost|
      mpost.destroy if marker =~ mpost.note
    }
    Meet.all.each {|meet|
      meet.destroy if marker =~ meet.name
    }
  end
  def self.should(cond, ok_message="", ng_message="")
    if cond
      puts "PASS" + (!ok_message.empty? ? ": #{ok_message}" : "")
    else
      puts "FAIL" + (!ng_message.empty? ? ": #{ng_message}" : "")
    end
  end
  def self.should_rsp(rsp)
    if !rsp.ok?
      should(false, "", "JSON return code #{rsp.code}")
      #raise
    end
  end
end
