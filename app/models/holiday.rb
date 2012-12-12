class Holiday < ActiveRecord::Base

  LOCATIONS = { 1 => 'Manila', 2 => 'Cebu', 3 => 'Manila & Cebu', 4 => 'Australia', 5 => 'US', 6 => 'All'}
  
  validates_presence_of :title, :description, :location, :event_date
  
end
