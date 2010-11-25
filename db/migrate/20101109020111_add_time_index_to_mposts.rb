class AddTimeIndexToMposts < ActiveRecord::Migration
  def self.up
    add_index :mposts, :time
    add_column :mposts, :lerror, :float
  end

  def self.down
    remove_index :mposts, :time
    remove_column :mposts, :lerrror
  end
end
