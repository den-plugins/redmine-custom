require_dependency 'version'

module Custom
  module VersionPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        before_save :set_completed_on, :if => :state
#        after_save :update_parent_status, :if => :has_parent?
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def set_completed_on
        if self.state.eql?(3)
          self.completed_on = (self.completed_on ? self.completed_on : Date.today)
        else
          self.completed_on = nil
        end
      end
    end
  end
end
