class AddMeetIdToChatters < ActiveRecord::Migration
  def self.up
    add_column :chatters, :meet_id, :integer
    add_index :chatters, :meet_id
  end

  def self.down
    remove_index :chatters, :meet_id
    remove_column :chatters, :meet_id
  end
end
