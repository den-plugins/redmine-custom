class AddDefaultRateToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :default_rate, :float
    add_column :users, :effective_date, :date
  end

  def self.down
    remove_column :users, :default_rate
    remove_column :users, :effective_date
  end
end
