class AddMeetIdIndex < ActiveRecord::Migration
  def self.up
    add_index :mposts, :meet_id
  end

  def self.down
    remove_index :mposts, :meet_id
  end
end
