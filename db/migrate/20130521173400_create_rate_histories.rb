class CreateRateHistories < ActiveRecord::Migration
  def self.up
    create_table :rate_histories do |t|
      t.column :default_rate, :float
      t.column :effective_date, :date
      t.column :end_date, :date
      t.column :updated_at, :date
      t.references :user
    end
  end

  def self.down
    drop_table :rate_histories
  end
end
