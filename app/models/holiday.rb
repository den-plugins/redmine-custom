class Holiday < ActiveRecord::Base

  LOCATIONS = { 1 => 'Manila', 2 => 'Cebu', 3 => 'Manila & Cebu', 4 => 'Australia', 5 => 'US', 6 => 'All'}
  
  validates_presence_of :title, :description, :location, :event_date
  
  def holiday_on_member_location?(user)
		holiday_location = Holiday::LOCATIONS[location]
		user_location = user.location

		holiday_location.scan(user_location).present? || holiday_location.eql?("All") ? true : false
  end

end
