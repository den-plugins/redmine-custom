require_dependency 'issue'

module Custom
  module IssuePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        has_many :remaining_effort_entries, :dependent => :destroy
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
    
      def remaining_effort=(value)
        self.remaining_effort_entries.build(:remaining_effort => value, :created_on => Date.today)
      end
      
      def remaining_effort
        entry = RemainingEffortEntry.find(:last, :conditions => ["issue_id = #{self.id}"]) unless self.new_record?
        return entry.nil? ? nil : entry.remaining_effort
      end
      
    end
  end
end
