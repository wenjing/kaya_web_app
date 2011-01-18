class AddUsersLockVersion < ActiveRecord::Migration
  def self.up
    add_column :meets, :lock_version, :integer, :default => 0, :null => false
  end

  def self.down
    remove_column :meets, :lock_version
  end
end
