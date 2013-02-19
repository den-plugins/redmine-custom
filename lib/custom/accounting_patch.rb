# Associate accounting_type to projects and issues

module Custom
  module AccountingPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        belongs_to :accounting, :class_name => 'AccountingType', :foreign_key => 'acctg_type'
      end
    end

    module InstanceMethods
      def acctg_type=(atyp)
        self.accounting   = nil
        self[:acctg_type] = atyp
      end
    end
  end
end