class AddNoteToMposts < ActiveRecord::Migration
  def self.up
    add_column :mposts, :note, :string
  end

  def self.down
    remove_column :mposts, :note
  end
end
