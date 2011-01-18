class DropMicropostsTable < ActiveRecord::Migration
  def self.up
    remove_index :microposts, :user_id
    drop_table :microposts
    add_index :chatters, :created_at
    add_index :invitations, :created_at
  end

  def self.down
    create_table :microposts do |t|
      t.string   :content
      t.integer  :user_id
      t.datetime :created_at
      t.datetime :updated_at
    end
    add_index :microposts, :user_id
  end
end
