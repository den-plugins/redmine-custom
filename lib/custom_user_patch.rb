require_dependency 'user'

module Custom
  module UserPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        # additional account status
        const_set(:STATUS_ARCHIVED, 4)
        named_scope :active_and_archived, :conditions => "#{User.table_name}.status = #{User::STATUS_ACTIVE} or #{User.table_name}.status = #{User::STATUS_ARCHIVED}"
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def archived?
        status == User::STATUS_ARCHIVED
      end
    end
  end
end
