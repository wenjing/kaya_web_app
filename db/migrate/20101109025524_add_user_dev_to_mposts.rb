class AddUserDevToMposts < ActiveRecord::Migration
  def self.up
    add_column :mposts, :user_dev, :string
  end

  def self.down
    remove_column :mposts, :user_dev
  end
end
