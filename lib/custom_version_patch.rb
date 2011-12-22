require_dependency 'version'

module Custom
  module VersionPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        before_save :set_completed_on, :if => :state
        validate :disallow_accepted, :if => "state == 3"
#        after_save :update_parent_status, :if => :has_parent?

        named_scope :affectable_accepted, :conditions => ["state = 3"], :order => "effective_date DESC", :limit => 3
        named_scope :affectable_active, :conditions => ["state <> 1 and state <> 3"], :order => "effective_date DESC"
      end
    end
    
    module ClassMethods
      def affectable
        affectable_active + affectable_accepted
      end
    end
    
    module InstanceMethods
      def set_completed_on
        if self.state.eql?(3)
          self.completed_on = (self.completed_on ? self.completed_on : Date.today)
        else
          self.completed_on = nil
        end
      end

      def disallow_accepted
        open_tickets = fixed_issues.count(:id, :include => [:status], 
                           :conditions => "issues.status_id = issue_statuses.id AND issue_statuses.is_closed = FALSE")
        errors.add :state, :open_tickets_found if open_tickets > 0
      end
    end
  end
end
