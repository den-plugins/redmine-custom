require_dependency 'project'

module Custom
  module ProjectPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        
        # override project-members association to include archived users
        undef :members
        has_many :members, :include => :user, :conditions => "#{User.table_name}.status=#{User::STATUS_ACTIVE} or #{User.table_name}.status=#{User::STATUS_ARCHIVED}"
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def admin?
        !!project_type.to_s.downcase['admin']
      end

      def closed?
        temp = custom_values.detect{|x| x.custom_field.name.downcase["closure"]}
        (temp and !temp.value.blank?) ? true : false
      end
    end
  end
end
