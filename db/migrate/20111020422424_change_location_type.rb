class ChangeLocationType < ActiveRecord::Migration
  def self.up
    remove_column :holidays, :location
    add_column :holidays, :location, :integer 
  end

  def self.down
    remove_column :holidays, :location
  end
end
