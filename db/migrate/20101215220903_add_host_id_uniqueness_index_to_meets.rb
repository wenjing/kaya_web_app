class AddHostIdUniquenessIndexToMeets < ActiveRecord::Migration
  def self.up
    add_index :meets, :host_id, :unique => true
  end

  def self.down
    remove_index :meets, :host_id
  end
end
