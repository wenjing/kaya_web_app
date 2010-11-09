class CreateMpostRecords < ActiveRecord::Migration
  def self.up
    create_table :mpost_records do |t|
      t.int :mpost_id
      t.datetime :time
      t.index :time

      t.timestamps
    end
  end

  def self.down
    drop_table :mpost_records
  end
end
