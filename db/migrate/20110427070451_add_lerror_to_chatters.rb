class AddLerrorToChatters < ActiveRecord::Migration
  def self.up
    add_column :chatters, :lerror, :float
  end

  def self.down
    remove_column :chatters, :lerror
  end
end
