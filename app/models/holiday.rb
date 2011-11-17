class Holiday < ActiveRecord::Base

  validates_presence_of :title, :description, :location, :event_date
  
  def self.locations
    @locations = CustomField.first(:conditions => "type = 'UserCustomField' and name = 'Location'")
    return @locations.possible_values
  end

  def self.get_location
    count = 0 
    location = []
    Holiday.locations.each do |loc|
      location[count] = loc, count
      count += 1
    end
    return location
  end

end
