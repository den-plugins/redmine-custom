require_dependency 'member'

module Custom
  module MemberPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        before_destroy :destroy_only_if_no_logs
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def destroy_only_if_no_logs
        if TimeEntry.find(:first, :conditions => ["project_id=? and user_id=?", project_id, user_id])
          errors.add_to_base("Cannot delete members with log hours.")
          return false
        end
      end
    end
  end
end
