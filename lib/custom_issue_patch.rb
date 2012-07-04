require_dependency 'issue'

module Custom
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        alias_method_chain :move_to, :copy
        attr_accessor :predefined_tasks, :old_status
        
        has_many :remaining_effort_entries, :dependent => :destroy
        before_save :remember_old_status, :if => "!children.empty?"
        before_save :update_children_iterations, :if => "!children.empty? and fixed_version_id_changed?"
        after_save :is_closed_issue_effects, :if => :closed?
        after_save :update_parent_status, :if => :has_parent?
        after_save :closing_parent_status, :if => "closed? and !children.empty?"
        after_create :auto_create_tasks, :if => "feature? and !predefined_tasks.nil?"
        after_update :auto_create_tasks, :if => "feature? and !predefined_tasks.nil?"
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods

      #TODO: Refactor
      def update_parent_status(parent_issue = parent.issue_from)
        closed_issues = parent_issue.children.collect{|x| x.closed?}
        if closed_issues.include? false or closed_issues.empty?
           in_progress_issues = parent_issue.children.collect{|x| !x.status.name.eql? "New" and !x.status.name.eql? "Assigned" and !x.status.name.eql? "Reopened" and !x.status.name.eql? "Open"}
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
      
      def update_children_iterations
        children.each do |child|
          child.fixed_version = fixed_version
          begin
          if child.save
            updated_on_will_change!
          end
          rescue ActiveRecord::StaleObjectError
            child.reload
            child.fixed_version = fixed_version
            if child.save
              updated_on_will_change!
            end
          end
        end
      end

      def remember_old_status
        self.old_status = self.status
      end

      def closing_parent_status
        children.each do |c|
          if !c.closed?
            self.status = old_status
            if self.save
              updated_on_will_change!
            end
            break
          end
        end
      end

      def delete_child_issues
        children.each do |c|
          puts "Deleting child #{c.id}..." 
          c.delete_child_issues
          c.destroy
        end
      end
      
      def is_closed_issue_effects
        unless remaining_effort.nil? or remaining_effort.to_i.eql?(0)
          self.remaining_effort = 0
          self.save
        end
      end
      
      def move_to_with_copy(new_project, new_tracker = nil, options = {})
        options ||= {}
        issue = options[:copy] ? self.clone : self
        transaction do
          if new_project && issue.project_id != new_project.id
            # delete issue relations
            unless Setting.cross_project_issue_relations?
              issue.relations_from.clear
              issue.relations_to.clear
            end
            # issue is moved to another project
            # reassign to the category with same name if any
            new_category = issue.category.nil? ? nil : new_project.issue_categories.find_by_name(issue.category.name)
            issue.category = new_category
            issue.fixed_version = nil
            issue.affects_version = nil
            issue.project = new_project
          end
          if new_tracker
            issue.tracker = new_tracker
          end
          if options[:copy]
            issue.custom_field_values = self.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
            issue.status = self.status
            # reassign modified attribute-assignment methods
            issue.acctg_type = self.acctg_type
            issue.priority_id = self.priority_id
            issue.estimated_hours = self.estimated_hours
            issue.remaining_effort = self.remaining_effort
          end
          if issue.save
            unless options[:copy]
              # Manually update project_id on related time entries
              TimeEntry.update_all("project_id = #{new_project.id}", {:issue_id => id})
            end
          else
            Issue.connection.rollback_db_transaction
            return false
          end
        end
        return issue
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
          self.remaining_effort_entries.build(:remaining_effort => value, :created_on => Date.today)
        end
        unless new_record? or value.blank?
          if @issue_before_change
            @current_journal ||= Journal.new(:journalized => self, :user => User.current, :notes => "")
            journalize_remaining_effort(old_value.to_f, value.to_f)
          end
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
        ptasks = [
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
        predefined_tasks.each do |task_subject|
          @task = Issue.new
          @task.project = Project.find(project_id)
          @task.tracker_id = 4
          @task.subject = @task.description = (task_subject + " - #{subject}")
          #@task.description = @task.subject
          @task.fixed_version_id = fixed_version_id
          @task.status = IssueStatus.default
          @task.priority = Enumeration.find(4)
          @task.acctg_type = acctg_type
          @task.start_date = Date.today
          @task.author = User.current
          if @task.save
            @relation = IssueRelation.new()
            @relation.issue_from = Issue.find(id)
            @relation.relation_type = "subtasks"
            @relation.issue_to = @task
            @relation.save
          end
        end
      end

      def is_transferable?
        time_entries.empty? and !closed? and remaining_effort == estimated_hours and children_transferable?
      end

      def can_be_carried_over?
        !time_entries.empty? and !closed? and remaining_effort != 0 and children_carried_over?
      end

      def children_transferable?
        res = true
        temp = children.map(&:is_transferable?)
        res = false if (!temp.blank? && temp.include?(false))
        res
      end
      
      def custom_clone
        new_me = project.issues.build
        hash = attributes
        new_me.attributes = attributes
        new_me.attributes = {"start_date" => nil, "created_on" => nil, "updated_on" => nil}
        new_me.estimated_hours = estimated_hours
        new_me
      end
     
      def time_spent
        time_entries.map(&:hours).sum.to_f.round(2)
      end

      def children_carried_over?
        res = true
        temp = children.map(&:can_be_carried_over?)
        res = false if (!temp.blank? && temp.include?(false))
        res
      end
      
    end
  end
end
