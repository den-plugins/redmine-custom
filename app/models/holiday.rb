class Holiday < ActiveRecord::Base

  validates_presence_of :title, :description, :location, :event_date
  
  def self.locations
    @locations = CustomField.first(:conditions => "type = 'UserCustomField' and name = 'Location'")
    return @locations.possible_values
  end
end
