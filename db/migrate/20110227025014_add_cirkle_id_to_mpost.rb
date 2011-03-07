class AddCirkleIdToMpost < ActiveRecord::Migration
  def self.up
    add_column :mposts, :cirkle_id, :integer
  end

  def self.down
    remove_index :mposts, :cirkle_id
  end
end
