class AddTimeIndexToMeets < ActiveRecord::Migration
  def self.up
    add_index :meets, :time
  end

  def self.down
    remove_index :meets, :time
  end
end
