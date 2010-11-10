class CreateMpostRecords < ActiveRecord::Migration
  def self.up
    create_table :mpost_records do |t|
      t.integer :mpost_id
      t.datetime :time

      t.timestamps
    end
    add_index :mpost_records, :time
  end

  def self.down
    drop_table :mpost_records
  end
end
