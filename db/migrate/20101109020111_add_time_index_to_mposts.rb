class AddTimeIndexToMposts < ActiveRecord::Migration
  def self.up
    add_index :mposts, :time
  end

  def self.down
    remove_index :mposts, :time
  end
end
