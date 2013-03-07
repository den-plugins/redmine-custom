require_dependency 'time_entry'

module Custom
  module TimeEntryPatch
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        unloadable
        validate :revalidate
        validate :allow_logging
      end
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      def allow_logging
        if project.is_admin_project? && (project.archived? || past_closure_date || !time_log_locked?(spent_on) || !project.user_allocated_on_proj(user_id, spent_on))
          errors.add_to_base l(:error_project_archived) if project.archived?
          errors.add_to_base l(:error_project_closed) if past_closure_date
          errors.add_to_base l(:error_project_time_log_locked) if !time_log_locked?(spent_on)
          errors.add_to_base l(:error_timelog_project_allocation) if !project.user_allocated_on_proj(user_id, spent_on)
        else
          if project.is_dev_project? && (project.archived? || past_closure_date || !time_log_locked?(spent_on) || !project.user_allocated_on_proj(user_id, spent_on))
            errors.add_to_base l(:error_project_archived) if project.archived?
            errors.add_to_base l(:error_project_closed) if past_closure_date
            errors.add_to_base l(:error_project_time_log_locked) if !time_log_locked?(spent_on)
            errors.add_to_base l(:error_timelog_project_allocation) if !project.user_allocated_on_proj(user_id, spent_on)
          end
        end
      end

      def past_closure_date
        closure_date = project.custom_field_values.detect{|v| v.value.present? && v.custom_field_id.eql?(32) } 
        (closure_date.present? && closure_date.value.to_date >= spent_on) || closure_date.blank? ? false : true
      end

      def revalidate
        # user not allowed to log more than 24 hours
        if hours.present?
          total_hours = user.time_entries.select {|e| e.spent_on.eql?(spent_on) }.sum(&:hours)
          if hours_changed?
            old_entry, new_entry = changes['hours']
            total_hours += (new_entry.to_f - old_entry.to_f)
          end
          errors.add_to_base l(:error_timelog_24hr_limit) unless total_hours <= 24
          # check accounting_type of project
          issue_is_billable = (issue.acctg_type == Enumeration.find_by_name('Billable').id) ? true : false
          # user not allowed to log if not a member of project
          if project.project_type and project.project_type.scan(/^(Admin)/).flatten.present?
            unless project.members.detect {|m| m.user_id == user_id}
              errors.add_to_base l(:error_timelog_project_membership)
              errors.add_to_base l(:error_timelog_project_allocation)
            end
          else
            if membership=project.members.project_team.detect {|m| m.user_id == user_id}
              member_is_billable = membership.billable?(spent_on, spent_on)
              allocated = membership.allocated?(spent_on)
              errors.add_to_base l(:error_timelog_project_allocation) unless (issue_is_billable && member_is_billable && allocated) || (!issue_is_billable && allocated)
            else
              errors.add_to_base l(:error_timelog_project_membership)
              errors.add_to_base l(:error_timelog_project_allocation)
            end
          end
          # user is not allowed to log if project is fixed bid and budget is consumed
          if project.billing_model and project.billing_model.scan(/^(Fixed)/).flatten.present?
            budget_computation(project_id)
          end
        end
      end
      
      def budget_computation(project_id)
        if issue.acctg_type == Enumeration.find_by_name('Billable').id
          bac_amount = project.project_contracts.all.sum(&:amount)
          contingency_amount = 0
          actuals_to_date = 0
          project_budget = 0

          pfrom, afrom, pto, ato, maintenance_end_date = project.planned_start_date, project.actual_start_date, project.planned_end_date, project.actual_end_date, project.maintenance_end
          to = maintenance_end_date ? maintenance_end_date : (ato || pto)

          if pfrom && to
            team = project.members.project_team.all
            reporting_period = (Date.today)
            forecast_range = get_weeks_range(pfrom, to)
            actual_range = get_weeks_range((afrom || pfrom), reporting_period)
            cost = project.monitored_cost(forecast_range, actual_range, team)
            actual_list = actual_range.collect {|r| r.first }
            cost.each do |k, v|
              actuals_to_date += v[:actual_cost] if actual_list.include?(k.to_date)
            end
            project_budget = bac_amount + contingency_amount
          end
          #include current time entry's amount
          member = team.detect{|m| m.user_id == user_id}
          errors.add_to_base l(:error_timelog_budget_consumed) if (project_budget - actuals_to_date) < 0
        end
      end

      def time_log_locked?(spent_on)
        project.lock_time_logging >= spent_on ? false : true rescue true
      end

    end
  end
end
