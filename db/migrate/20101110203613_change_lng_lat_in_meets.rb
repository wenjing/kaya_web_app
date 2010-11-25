class ChangeLngLatInMeets < ActiveRecord::Migration
  def self.up
    remove_column :meets, :lng
    remove_column :meets, :lat
    add_column :meets, :lng, :decimal, :precision => 15, :scale => 10
    add_column :meets, :lat, :decimal, :precision => 15, :scale => 10
  end

  def self.down
    remove_column :meets, :lat
    remove_column :meets, :lng
    add_column :meets, :lat, :decimal
    add_column :meets, :lng, :decimal
  end
end
