require_dependency 'issue_relation'

module Custom
  module IssueRelationPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        def validate
          if issue_from && issue_to
            errors.add :issue_to_id, :invalid if issue_from_id == issue_to_id
            errors.add :issue_to_id, :not_same_project unless issue_from.project_id == issue_to.project_id || Setting.cross_project_issue_relations?
            errors.add_to_base :circular_dependency if issue_to.all_dependent_issues.include? issue_from
            errors.add :issue_to_id, 
                         :invalid if relation_type.eql? "subtasks" and (issue_from.tracker_id.eql? 2 or issue_from.tracker_id.eql? 4) and issue_to.tracker_id.eql? 1
            errors.add :issue_to_id, 
                         :invalid if relation_type.eql? "subtasks" and (issue_to.tracker_id.eql? 2 or issue_to.tracker_id.eql? 4) and issue_from.tracker_id.eql? 1
          end
        end
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods

      
    
    end
  end
end
