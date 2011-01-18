class CreateMviews < ActiveRecord::Migration
  def self.up
    create_table :mviews do |t|
      t.integer :user_id
      t.integer :meet_id
      t.string :name
      t.string :location
      t.datetime :time
      t.text :description

      t.timestamps
    end
    add_index :mviews, [:user_id, :meet_id], :unique => true
  end

  def self.down
    drop_table :mviews
  end
end
