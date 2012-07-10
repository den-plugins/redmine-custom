require_dependency 'journal_detail'

module Custom
  module JournalDetailPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        
        def before_save
          puts "Overriding JournalDetail#before_save in vendor/plugins/redmine_custom/lib/custom_journal_detail_patch.rb"
        end

        def save(*args)
          value_valid? ? super : false
        end
      end
    end
    
    module InstanceMethods
      def value_valid?
        sp = IssueCustomField.find_by_name("Story Points").id
        if old_value.to_s.strip != value.to_s.strip
          prop_key.to_i == sp ? old_value.to_f != value.to_f : true
        else
          false
        end
      end
    end
  end
end
