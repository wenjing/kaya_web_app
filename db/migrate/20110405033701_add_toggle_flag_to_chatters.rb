class AddToggleFlagToChatters < ActiveRecord::Migration
  def self.up
    add_column :chatters, :toggle_flag, :boolean, :default => false
    add_column :meets,    :toggle_flag, :boolean, :default => false
  end

  def self.down
    remove_column :meets,    :toggle_flag
    remove_column :chatters, :toggle_flag
  end
end
