class AddCreatedAtIndexToMposts < ActiveRecord::Migration
  def self.up
    add_index :mposts, :created_at
  end

  def self.down
    remove_index :mposts, :created_at
  end
end
