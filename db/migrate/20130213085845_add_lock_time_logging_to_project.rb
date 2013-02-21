class AddLockTimeLoggingToProject < ActiveRecord::Migration
  def self.up
  	add_column :projects, :lock_time_logging, :date, :default => nil
  end

  def self.down
  	remove_column :projects, :lock_time_logging
  end
end
