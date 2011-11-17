class ChangeLocationType < ActiveRecord::Migration
  def self.up
    change_column :holidays, :location, :integer 
  end

  def self.down
    remove_column :holidays, :location
  end
end
