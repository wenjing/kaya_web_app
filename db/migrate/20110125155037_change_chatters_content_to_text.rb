class ChangeChattersContentToText < ActiveRecord::Migration
  def self.up
    change_table :chatters do |t|
      t.change :content, :text
    end
  end

  def self.down
    change_table :chatters do |t|
      t.change :content, :text
    end
  end
end
