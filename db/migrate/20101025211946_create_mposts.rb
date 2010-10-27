class CreateMposts < ActiveRecord::Migration
  def self.up
    create_table :mposts do |t|
      t.integer :user_id
      t.integer :meet_id
      t.datetime :time
      t.decimal :lng
      t.decimal :lat
      t.text :devs

      t.timestamps
    end
    add_index :mposts, :user_id
  end

  def self.down
    drop_table :mposts
  end
end
