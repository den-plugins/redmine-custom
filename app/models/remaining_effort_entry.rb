class RemainingEffortEntry < ActiveRecord::Base

  belongs_to :issue
  validates_numericality_of :remaining_effort, :allow_nil => true
  
  before_create :set_default
  after_update :set_estimated_hours

  # This method sets the default value of <tt>:estimated_hours</tt>.
  # do not save if remaining_effort is NULL and is not first entry
  # do not save if remaining_effort is NULL and estimated_hours is NULL
  # do not save if value is the same as the latest entry
  def set_default
    issue = Issue.find(self.issue.id)
    self.remaining_effort = issue.estimated_hours if remaining_effort.nil? && issue.estimated_hours && !issue.remaining_effort
    return false if (remaining_effort.nil? && (issue.remaining_effort or issue.estimated_hours.nil?)) or
                                (remaining_effort && remaining_effort == issue.remaining_effort)
  end

  def set_estimated_hours
    puts "+++++++++++++++++++++++++"
    issue = Issue.find(self.issue.id)
    issue.estimated_hours = 0 if issue.tracker_id.eql? 4 and !issue.parent
  end

end
