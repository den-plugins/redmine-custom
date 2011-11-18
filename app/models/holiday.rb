class Holiday < ActiveRecord::Base

  LOCATIONS = { 1 => 'Manila', 2 => 'Cebu', 3 => 'Cebu/Manila', 4 => 'Australia', 5 => 'US'}
  
  validates_presence_of :title, :description, :location, :event_date
  
end
