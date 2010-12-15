class CreateInvitations < ActiveRecord::Migration
  def self.up
    create_table :invitations do |t|
      t.integer :meet_id
      t.integer :user_id
      t.text :invitee

      t.timestamps
    end
  end

  def self.down
    drop_table :invitations
  end
end
