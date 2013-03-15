class AddSowRateToResourceAllocation < ActiveRecord::Migration
  def self.up
    add_column :resource_allocations, :sow_rate, :float
  end

  def self.down
    remove_column :resource_allocations, :sow_rate
  end
end
