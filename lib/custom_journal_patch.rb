require_dependency 'journal'

module Custom
  module JournalPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        
        def save(*args)
          puts "Overriding Journal#save in vendor/plugins/redmine_custom/lib/custom_journal_detail_patch.rb"
          # Do not save an empty journal
          ((details.empty? or value_not_changed?(details)) and notes.blank?) ? false : super
        end
      end
    end

    module InstanceMethods
      def value_not_changed?(details)
        sp = IssueCustomField.find_by_name("Story Points").id
        details = details.select{|x| (x.old_value.to_s.strip != x.value.to_s.strip)}
        details.select{|x| x.prop_key.to_i == sp ? x.old_value.to_f != x.value.to_f : true}.empty?
      end
    end
  end
end
