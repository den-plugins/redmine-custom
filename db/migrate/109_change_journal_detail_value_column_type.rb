class ChangeJournalDetailValueColumnType < ActiveRecord::Migration
  def self.up
    change_column :journal_details, :value, :text, :limit => nil
    change_column :journal_details, :old_value, :text, :limit => nil
  end

  def self.down
  end
end
