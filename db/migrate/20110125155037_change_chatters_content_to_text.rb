class ChangeChattersContentToText < ActiveRecord::Migration
  def self.up
    change_table :chatters do |t|
      t.change :content, :text, :limit=>500
    end
  end

  def self.down
    change_table :chatters do |t|
      t.change :content, :text, :limit=>250
    end
  end
end
