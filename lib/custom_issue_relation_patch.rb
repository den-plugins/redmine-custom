require_dependency 'issue_relation'

module Custom
  module IssueRelationPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        validate :validate_parentship
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def validate_parentship
        if issue_from && issue_to
          errors.add :issue_to_id,
                              :invalid if relation_type.eql? "subtasks" and (issue_from.tracker_id.eql? 2 or issue_from.tracker_id.eql? 4) and issue_to.tracker_id.eql? 1
          errors.add :issue_to_id,
                              :invalid if relation_type.eql? "subtasks" and (issue_to.tracker_id.eql? 2 or issue_to.tracker_id.eql? 4) and issue_from.tracker_id.eql? 1
          errors.add :issue_to_id,
                              :one_parent_allowed if relation_type.eql? "subtasks" and issue_to.parent.present?
        end
      end
    end

  end
end
