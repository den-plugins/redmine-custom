require_dependency 'issue'

module Custom
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development

        attr_accessor :predefined_tasks
        
        has_many :remaining_effort_entries, :dependent => :destroy
        after_save :is_closed_issue_effects, :if => :closed?
        after_save :update_parent_status, :if => :has_parent?
        after_create :auto_create_tasks, :if => "feature? and !predefined_tasks.nil?"
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods

      #TODO: Refactor
      def update_parent_status(parent_issue = parent.issue_from)
        closed_issues = parent_issue.children.collect{|x| x.closed?}
        if closed_issues.include? false or closed_issues.empty?
           in_progress_issues = parent_issue.children.collect{|x| !x.status.name.eql? "New"}
           if in_progress_issues.include? true
             parent_issue.status = IssueStatus.find_by_name("In Progress")
           else
              parent_issue.status = IssueStatus.find_by_name("New")
           end
        else
          #puts "closing parent"
          parent_issue.status = IssueStatus.find_by_name("Closed")
        end
        if parent_issue.save
          updated_on_will_change!
        end
      end
      
      def is_closed_issue_effects
        self.remaining_effort = 0 unless remaining_effort.nil? or remaining_effort.to_i.eql?(0)
        self.send(:update_without_callbacks)
      end
      
      def parent_issue
        parent.issue_from
      end
  
      def not_parent?
        !children.any? and parent
      end

      def has_parent?
        !parent.nil?
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
      
      #TODO: Refactor (in auto setting remaining_effort to 0 if issue is closed)
      def remaining_effort=(value)
        old_value = remaining_effort
        return false if old_value.to_i.eql?(0) && IssueStatus.find(status_id).is_closed?
        if entry = RemainingEffortEntry.find(:first, :conditions => ["issue_id = ? AND created_on = ?", self.id, Date.today])
          entry.update_attributes({:remaining_effort => value}) unless value.blank?
        else
          if value.to_i.eql?(0) && closed?
            self.remaining_effort_entries.create(:remaining_effort => value, :created_on => Date.today)
          else
            self.remaining_effort_entries.build(:remaining_effort => value, :created_on => Date.today)
          end
        end
        unless new_record? or value.blank?
          @current_journal ||= Journal.new(:journalized => self, :user => User.current, :notes => "")
          journalize_remaining_effort(old_value.to_f, value.to_f)
        end
      end
      
      def remaining_effort
        entry = RemainingEffortEntry.find(:first, :conditions => ["issue_id = #{id} and remaining_effort is not null"], :order => "created_on DESC") unless new_record?
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

      def predef_tasks
      [
        "Requirements analysis",
        "Analysis of Use case docs",
        "QA testing",
        "Coding",
        "Functional Validation",
        "Code Review",
        "Unit testing",
        "Defect analysis and fixing",
        "Test Case Creation",
        "Integration"
      ]
      end

      def auto_create_tasks
#        predefined_tasks = [
#          "Requirements analysis - #{subject}",
#          "Analysis of Use case docs - #{subject}",
#          "QA testing - #{subject}",
#          "Coding - #{subject}",
#          "Functional Validation - #{subject}",
#          "Code Review - #{subject}",
#          "Unit testing - #{subject}",
#          "Defect analysis and fixing - #{subject}",
#          "Test Case Creation - #{subject}",
#          "Integration"
#        ]
        predefined_tasks.each do |task_subject|
          @task = Issue.new
          @task.project = Project.find(project_id)
          @task.tracker_id = 4
          @task.subject = (task_subject.eql?("Integration"))? task_subject : (task_subject + " - #{subject}")
          @task.fixed_version_id = fixed_version_id
          @task.status = IssueStatus.default
          @task.priority = Enumeration.find(4)
          @task.acctg_type = 11
          @task.start_date = Date.today
          @task.author = User.current
          if @task.save
            @relation = IssueRelation.new()
            @relation.issue_from = Issue.find(id)
            @relation.relation_type = "subtasks"
            @relation.issue_to = @task
            @relation.save
          end
          puts "DONE >> #{task_subject}"
        end
      end
      
    end
  end
end
