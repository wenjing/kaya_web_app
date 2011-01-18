class AddMeetsLockVersion < ActiveRecord::Migration
  def self.up
    add_column :meets, :lock_version, :integer, :default => 0, :null => false
    add_column :meets, :hoster_id, :integer
    add_column :meets, :cached_info, :text
    add_index :meets, :hoster_id
    add_index :chatters, :user_id
    add_index :invitations, :user_id
    add_index :invitations, :meet_id

    # Fill in existing Meet records' cache info
    Meet.find(:all).each {|meet|
      meet.extract_information
      meet.save
    }
  end

  def self.down
    remove_column :meets, :lock_version
    remove_column :meets, :hoster_id
    remove_column :meets, :cached_info
    remove_index :meets, :hoster_id
    remove_index :chatters, :user_id
    remove_index :invitations, :user_id
    remove_index :invitations, :meet_id
  end
end
