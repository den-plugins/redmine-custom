require_dependency 'issue'

module Custom
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        has_many :remaining_effort_entries, :dependent => :destroy
        after_save :update_parent_status, :if => :not_parent?
        
#TODO: Refactor
      def update_parent_status
        closed_issues = parent_issue.children.collect{|x| x.closed?}
        if closed_issues.include? false
           in_progress_issues = parent_issue.children.collect{|x| !x.status.name.eql? "New"}
           if in_progress_issues.include? true
             parent_issue.status = IssueStatus.find_by_name("In Progress")
           else
              parent_issue.status = IssueStatus.find_by_name("New")
           end
        else
          puts "closing parent"
          parent_issue.status = IssueStatus.find_by_name("Closed")
        end
        if parent_issue.save
          updated_on_will_change!
        end
      end

      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods

      def parent_issue
        parent.issue_from
      end
  
      def not_parent?
        !children.any? && parent
      end
      
      def bug?
        self.tracker_id.eql? 1
      end
      
      def feature?
        self.tracker_id.eql? 2
      end
       
      def support?
        self.tracker_id.eql? 3
      end
      
      def task?
        self.tracker_id.eql? 4
      end
    
      def remaining_effort=(value)
        old_value = remaining_effort
        self.remaining_effort_entries.build(:remaining_effort => value, :created_on => Date.today)
        unless new_record? or value.to_f == 0
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
