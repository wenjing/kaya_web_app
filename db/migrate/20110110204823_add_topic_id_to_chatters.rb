class AddCommentIdToChatters < ActiveRecord::Migration
  def self.up
    remove_column :mposts, :status
    add_column :mposts, :status, :integer, :default => 0
    add_column :mposts, :invitation_id, :integer
    remove_column :users, :status
    add_column :users, :status, :integer, :default => 0
    add_column :users, :temp_password, :string
    add_column :meets, :type, :integer
    add_column :chatters, :topic_id, :integer
    add_column :chatters, :cached_info, :text
    remove_column :chatters, :status

    add_index :mposts, :status
    add_index :mposts, :invitation_id
    add_index :users, :status
    add_index :meets, :type
    add_index :mviews, :created_at
    add_index :chatters, :topic_id
    add_index :chatters, :updated_at

    # Fill in existing Meet records' info
    Meet.find(:all).each {|meet|
      meet.extract_information
      meet.update_chatter_counts
      meet.save
    }
  end

  def self.down
    remove_index :mposts, :status
    remove_index :mposts, :invitation_id
    remove_index :users, :status
    remove_index :meets, :type
    remove_index :mviews, :created_at
    remove_index :chatters, :topic_id
    remove_index :chatters, :updated_at

    remove_column :mposts, :status
    add_column :mposts, :status, :integer
    add_column :mposts, :invitation_id
    remove_column :users, :status
    add_column :users, :status, :integer
    remove_column :users, :temp_password
    remove_column :meets, :type, :integer
    remove_column :chatters, :topic_id
    remove_column :chatters, :cached_info
    add_column :chatters, :status, :integer
  end
end
