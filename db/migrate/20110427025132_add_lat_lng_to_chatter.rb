class AddLatLngToChatter < ActiveRecord::Migration
  def self.up
    add_column :chatters, :lng, :decimal, :precision => 15, :scale => 10
    add_column :chatters, :lat, :decimal, :precision => 15, :scale => 10
  end

  def self.down
    remove_column :chatters, :lat
    remove_column :chatters, :lng
  end
end
