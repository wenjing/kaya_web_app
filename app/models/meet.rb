# == Schema Information
# Schema version: 20101027191028
#
# Table name: meets
#
#  id             :integer         not null, primary key
#  name           :string(255)
#  description    :text
#  time           :datetime
#  location       :string(255)
#  street_address :string(255)
#  city           :string(255)
#  state          :string(255)
#  zip            :string(255)
#  country        :string(255)
#  lng            :decimal(, )
#  lat            :decimal(, )
#  users_count    :integer
#  image_url      :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#

class Meet < ActiveRecord::Base

    attr_accessible :name, :description, :time, 
                    :location, :street_address, :city, 
                    :state, :zip, :country, 
                    :users_count, :lng, :lat,
                    :image_url

    has_many :mposts
    has_many :users,  :through => :mposts

    validates :name,  :presence => true,
                      :length   => { :maximum => 250 }
    validates :time,  :presence => true
    validates :lng,  :presence => true
    validates :lat,  :presence => true
    validates :users_count, :presence => true

    default_scope :order => 'meets.created_at DESC'

end
