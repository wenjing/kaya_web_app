class ChangeChattersContentToText < ActiveRecord::Migration
  def self.up
    remove_column :chatters, :content
    add_column :chatters, :content, :text
  end

  def self.down
    remove_column :chatters, :content
    add_column :chatters, :content, :string
  end
end
