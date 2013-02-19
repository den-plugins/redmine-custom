require_dependency 'issue_relation'

module Custom
  module IssueRelationPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        #after_save :update_parent_status, :if => :is_related_by_subtask?
        #after_save :update_parent_effort, :if => :issue_task?
        after_destroy :update_parent_status_on_delete
        validate :validate_parentship
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def after_save
        if is_related_by_subtask?
          issue_to.update_parent_status(issue_from)
          issue_to.fixed_version = issue_from.fixed_version
          if issue_to.task?
            # update parent efforts
            issue_from.estimated_hours = 0
            issue_from.remaining_effort = 0
            issue_from.save
          end
          issue_to.save
        end
      end

      def update_parent_status_on_delete
        issue = Issue.find issue_from
        issue.update_parent_status(issue)
      end
      
      def is_related_by_subtask?
        relation_type.eql? "subtasks" and issue_from
      end
      
      def validate_parentship
        if issue_from && issue_to
          #errors.add :issue_to_id,
          #:invalid if relation_type.eql? "subtasks" and issue_from.tracker_id.eql? 2 and issue_to.tracker_id.eql? 1
          errors.add :issue_to_id,
            :invalid if relation_type.eql? "subtasks" and issue_from.tracker_id.eql? 4 and issue_to.tracker_id.eql? 2
          errors.add :issue_to_id,
                              :invalid if relation_type.eql? "subtasks" and !issue_to.tracker_id.eql? 1 and issue_from.tracker_id.eql? 1
          errors.add :issue_to_id,
                              :one_parent_allowed if relation_type.eql? "subtasks" and issue_to.parent.present?
        end
      end
    end
  end
end
