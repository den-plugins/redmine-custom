require_dependency 'journal_detail'

module Custom
  module JournalDetailPatch
    def self.included(base)
      unloadable
      base.class_eval do
        
        def before_save
          puts "Overriding JournalDetail#before_save in vendor/plugins/redmine_custom/lib/custom_journal_detail_patch.rb"
        end

        def save(*args)
          super
        end
      end
    end
  end
end
