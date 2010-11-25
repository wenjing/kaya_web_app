class ChangeLngLatInMposts < ActiveRecord::Migration
  def self.up
    remove_column :mposts, :lng
    remove_column :mposts, :lat
    add_column :mposts, :lng, :decimal, :precision => 15, :scale => 10
    add_column :mposts, :lat, :decimal, :precision => 15, :scale => 10
  end

  def self.down
    remove_column :mposts, :lat
    remove_column :mposts, :lng
    add_column :mposts, :lat, :decimal
    add_column :mposts, :lng, :decimal
  end
end
