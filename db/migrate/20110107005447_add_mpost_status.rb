class AddMpostStatus < ActiveRecord::Migration
  def self.up
    add_column :mposts, :status, :integer, :default => 0
    add_column :chatters, :status, :integer, :default => 0
    add_column :meets, :type, :integer
    remove_column :users, :pending
    add_column :users, :status, :integer, :default => 0
  end

  def self.down
    remove_column :users, :status
    add_column :users, :pending, :boolean
    remove_column :meets, :status
    remove_column :chatters, :status
    remove_column :mposts, :type
  end
end
