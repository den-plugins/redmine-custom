module Custom
  module IssuePatch
    def self.included(base)
      base.class_eval do
        unloadable

        safe_attributes 'acctg_type', :if => lambda {|issue, user| issue.new_record? || user.allowed_to?(:edit_issues, issue.project) }
      end
    end
  end
end