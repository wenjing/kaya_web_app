class AddHostModeCollisionHostIdToMposts < ActiveRecord::Migration
  def self.up
    add_column :mposts, :host_mode, :integer
    add_column :mposts, :collision, :boolean
    add_column :mposts, :host_id, :string
  end

  def self.down
    remove_column :mposts, :host_id
    remove_column :mposts, :collision
    remove_column :mposts, :host_mode
  end
end
