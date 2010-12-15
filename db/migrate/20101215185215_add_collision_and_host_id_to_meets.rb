class AddCollisionAndHostIdToMeets < ActiveRecord::Migration
  def self.up
    add_column :meets, :collision, :boolean
    add_column :meets, :host_id, :string
  end

  def self.down
    remove_column :meets, :host_id
    remove_column :meets, :collision
  end
end
