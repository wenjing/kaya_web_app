class RemoveUsersCountFromMeets < ActiveRecord::Migration
  def self.up
    remove_column :meets, :users_count
  end

  def self.down
    add_column :meets, :users_count, :string
  end
end
