class ChangeJournalDetailValueColumnType < ActiveRecord::Migration
  def self.up
    change_column :journal_details, :value, :text, :limit => nil
  end

  def self.down
  end
end
