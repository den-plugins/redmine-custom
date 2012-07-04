require_dependency 'custom_value'

module Custom
  module ValuePatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        before_save :assign_to_all_checker
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def assign_to_all_checker
        if custom_field.field_format == "bool" and value.nil?
          value = false
        end
      end
    end
  end
end
