require_dependency 'journal'

module Custom
  module JournalPatch
    def self.included(base)
      base.class_eval do
        unloadable
        
        def save(*args)
          puts "Overriding Journal#save in vendor/plugins/redmine_custom/lib/custom_journal_detail_patch.rb"
          # Do not save an empty journal
          ((details.empty? or details.select{|x| x.old_value.to_s.strip!="" or x.value.to_s.strip!=""}.empty?) and notes.blank?) ? false : super
        end
      end
    end
  end
end
