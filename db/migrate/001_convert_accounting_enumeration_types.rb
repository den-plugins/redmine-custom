class ConvertAccountingEnumerationTypes < ActiveRecord::Migration
  def self.up
    acctg_types = Enumeration.find_all_by_name(["Billable", "Non-billable"])
    acctg_types.each do |enum|
      enum[:type] = "AccountingType"
      enum.save
    end
  end

  def self.down
  end
end
