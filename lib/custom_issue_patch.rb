require_dependency 'issue'

module Custom
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        has_many :remaining_effort_entries, :dependent => :destroy
#-------still dirty-----------------
        def update_parent_status
        closed_issues = children.collect{|x| x.closed?}
        if closed_issues.include? false
           in_progress_issues = self.children.collect{|x| !x.status.name.eql? "New"}
           if in_progress_issues.include? true
             self.status = IssueStatus.find_by_name("In Progress")
           else
              self.status = IssueStatus.find_by_name("New")
           end
        else
          puts "closing parent"
          self.status = IssueStatus.find_by_name("Closed")
        end
        if self.save
          updated_on_will_change!
        end
      end
#----------------------------------
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
    
      def remaining_effort=(value)
        old_value = remaining_effort
        self.remaining_effort_entries.build(:remaining_effort => value, :created_on => Date.today)
        unless new_record?
          @current_journal ||= Journal.new(:journalized => self, :user => User.current, :notes => "")
          journalize_remaining_effort(old_value.to_f, value.to_f)
        end
      end
      
      def remaining_effort
        entry = RemainingEffortEntry.find(:last, :conditions => ["issue_id = #{self.id}"]) unless self.new_record?
        return entry.nil? ? nil : entry.remaining_effort
      end
      
      def journalize_remaining_effort(old_value, value)
        @current_journal.details << JournalDetail.new(:property => 'attr',
                                                      :prop_key => 'remaining_effort',
                                                      :old_value => old_value,
                                                      :value => value) unless value == old_value
      end

      def bug_feature_status_diff
        IssueStatus.all(:conditions => "name = 'For Monitoring' or name = 'Not a Defect' or name = 'Cannot Reproduce' or name = 'Feedback'")
      end
      
    end
  end
end
