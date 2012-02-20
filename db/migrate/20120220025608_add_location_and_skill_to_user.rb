class AddLocationAndSkillToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :location, :string
    add_column :users, :skill, :string
  end

  def self.down
    remove_column :users, :skill
    remove_column :users, :location
  end
end
