class RemainingEffortEntry < ActiveRecord::Base

  belongs_to :issue
  validates_numericality_of :remaining_effort, :allow_nil => true
  
  before_create :set_default

  # This method sets the default value of <tt>:estimated_hours</tt>.
  # do not save if remaining_effort is NULL and is not first entry
  # do not save if estimated_hours is NULL
  # do not save if value is the same as the latest entry
  def set_default
    unless RemainingEffortEntry.find(:first, :conditions => ["issue_id = #{issue_id}"]) && issue.estimated_hours.nil? && remaining_effort
      self.remaining_effort = issue.estimated_hours
    end
  end
end
