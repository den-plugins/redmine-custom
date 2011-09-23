require_dependency 'issue_relation'

module Custom
  module IssueRelationPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        after_save :update_parent_status
        after_destroy :update_parent_status_on_delete
        validate :validate_parentship

      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def update_parent_status
        issue = Issue.find issue_to
        issue.update_parent_status if issue.not_parent?
      end

      def update_parent_status_on_delete
        issue = Issue.find issue_from
        issue.update_parent_status(issue)
      end
      
      def validate_parentship
        if issue_from && issue_to
          errors.add :issue_to_id,
                              :invalid if relation_type.eql? "subtasks" and (issue_from.tracker_id == (2 || 4)) and issue_to.tracker_id != (2 || 4)
          errors.add :issue_to_id,
                              :invalid if relation_type.eql? "subtasks" and !issue_to.tracker_id.eql? 1 and issue_from.tracker_id.eql? 1
          errors.add :issue_to_id,
                              :one_parent_allowed if relation_type.eql? "subtasks" and issue_to.parent.present?
        end
      end
    end

  end
end
