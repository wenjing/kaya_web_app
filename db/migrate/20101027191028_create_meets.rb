class CreateMeets < ActiveRecord::Migration
  def self.up
    create_table :meets do |t|
      t.string :name
      t.text :description
      t.datetime :time
      t.string :location
      t.string :street_address
      t.string :city
      t.string :state
      t.string :zip
      t.string :country
      t.decimal :lng
      t.decimal :lat
      t.integer :users_count
      t.string :image_url

      t.timestamps
    end
  end

  def self.down
    drop_table :meets
  end
end
