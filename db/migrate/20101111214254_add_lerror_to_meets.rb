class AddLerrorToMeets < ActiveRecord::Migration
  def self.up
    add_column :meets, :lerror, :float
  end

  def self.down
    remove_column :meets, :lerror
  end
end
