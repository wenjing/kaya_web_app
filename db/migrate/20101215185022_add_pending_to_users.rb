class AddPendingToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :pending, :boolean
  end

  def self.down
    remove_column :users, :pending
  end
end
