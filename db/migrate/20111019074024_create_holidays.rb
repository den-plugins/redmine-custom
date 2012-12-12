class CreateHolidays < ActiveRecord::Migration
  def self.up
    create_table :holidays do |t|
      t.column :event_date, :date
      t.column :title, :string
      t.column :description, :string
      t.column :location, :string
    end
  end

  def self.down
    drop_table :holidays
  end	
end
