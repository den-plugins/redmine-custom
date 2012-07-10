require_dependency 'journal_detail'

module Custom
  module JournalDetailPatch
    def self.included(base)
      base.class_eval do
        unloadable
        
        def before_save
          puts "Overriding JournalDetail#before_save in vendor/plugins/redmine_custom/lib/custom_journal_detail_patch.rb"
        end

        def save(*args)
          (old_value.to_s.strip!="" or value.to_s.strip!="") ? super : false
        end
      end
    end
  end
end
