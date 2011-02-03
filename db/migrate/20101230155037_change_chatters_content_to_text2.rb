class ChangeChattersContentToText2 < ActiveRecord::Migration
  def self.up
    #remove_column :chatters, :content
    #add_column :chatters, :content, :text
    change_table :chatters do |t|
      t.change :content, :text
    end
  end

  def self.down
    #remove_column :chatters, :content
    #add_column :chatters, :content, :string
    change_table :chatters do |t|
      t.change :content, :string
    end
  end
end
