class ChangeDevsInMposts < ActiveRecord::Migration
  def self.up
    remove_column :mposts, :devs
    add_column :mposts, :devs, :text
#    add_column :mposts, :devs, :text, :limit=>50000
  end

  def self.down
    remove_column :mposts, :devs
    add_column :mposts, :devs, :text
  end
end
