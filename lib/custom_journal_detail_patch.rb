require_dependency 'journal_detail'

module Custom
  module JournalDetailPatch
    def self.included(base)
      base.class_eval do
        unloadable
        def before_save
          puts "Overriding core method before_save."
        end
      end
    end
  end
end
