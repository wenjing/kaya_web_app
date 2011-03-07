class AddCirkleIdToMeet < ActiveRecord::Migration
  def self.up
    add_column :meets, :cirkle_id, :integer
    add_index :meets, :cirkle_id
  end

  def self.down
    remove_index :meets, :cirkle_id
    remove_column :meets, :cirkle_id
  end
end
