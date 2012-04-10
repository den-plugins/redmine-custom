#*****************************************************************************
# controller that overrides some methods from issuescontoller
#
#*****************************************************************************

class CustomIssuesController < IssuesController

  skip_before_filter :authorize, :only => [:new, :find_project, :edit, :destroy]
  before_filter :custom_authorize, :only => [:new, :find_project, :edit, :destroy]
  before_filter :filter, :only => [:gantt, :calendar]
  skip_before_filter :find_optional_project, :only => [:gantt, :calendar]
  before_filter :custom_find_optional_project, :only => [:gantt, :calendar]
  
  def new
    @issue = Issue.new
    @issue.copy_from(params[:copy_from]) if params[:copy_from]
    @issue.project = @project
    @mode = 'main'
    # Tracker must be set before custom field values
    @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
    if @issue.tracker.nil?
      render_error 'No tracker is associated to this project. Please check the Project settings.'
      return
    end
    if params[:issue].is_a?(Hash)
      @issue.attributes = params[:issue]
      @issue.watcher_user_ids = params[:issue]['watcher_user_ids'] if User.current.allowed_to?(:add_issue_watchers, @project)
      @issue.predefined_tasks = params[:issue]['predefined_tasks']
    end
    @issue.author = User.current
    
    default_status = IssueStatus.default
    unless default_status
      render_error 'No default issue status is defined. Please check your configuration (Go to "Administration -> Issue statuses").'
      return
    end
    @issue.status = default_status
    @allowed_statuses = ([default_status] + default_status.find_new_statuses_allowed_to(User.current.role_for_project(@project), @issue.tracker)).uniq
    
    if params[:issue_from_id]
      @mode = "subtask"
      @relation = IssueRelation.new()
      @relation.issue_from = Issue.find(params[:issue_from_id])
      @relation.relation_type = params[:relation_type]
    end

    if request.get? || request.xhr?
      @issue.start_date ||= Date.today
    else
      requested_status = IssueStatus.find_by_id(params[:issue][:status_id])
      # Check that the user is allowed to apply the requested status
      @issue.status = (@allowed_statuses.include? requested_status) ? requested_status : default_status
      unless @issue.assigned_to.nil?
        @issue.errors.add_to_base "Cannot assign to resigned resource." if employee_status == "Resigned"
      end
      if @issue.errors.empty? && @issue.save
        if params[:relation]
          @relation = IssueRelation.new(params[:relation])
          if !params[:relation][:issue_from_id].blank?
            @relation.issue_from = Issue.find(params[:relation][:issue_from_id])
            @relation.issue_to = @issue
          else
            if !params[:relation][:issue_to_id].blank?
              @relation.issue_to = Issue.find(params[:relation][:issue_to_id])
              @relation.issue_from = @issue
            end
          end
          @relation.save
        end
        attach_files(@issue, params[:attachments])
        flash[:notice] = l(:notice_successful_create)
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        redirect_to(params[:continue] ? { :action => 'new', :tracker_id => @issue.tracker, :project_id => @project, :back_to => params[:back_to] } :
                                        (params[:back_to] || { :controller => 'issues', :action => 'show', :id => @issue }))
        return
      end
    end	
    @priorities = Enumeration.priorities
    @accounting = Enumeration.accounting_types
    @default = !@project.accounting.nil? ? @project.accounting.id : Enumeration.accounting_types.default.id if Enumeration.accounting_types
    render :template => 'issues/new', :layout => !request.xhr?
  end

  def gantt    
    @gantt = Redmine::Helpers::Gantt.new(params)
    retrieve_query
    if @query.valid?
      events = []
      # Issues that have start and due dates
      events += Issue.find(:all, 
                           :order => "start_date, due_date",
                           :include => [:tracker, :status, :assigned_to, :priority, :project], 
                           :conditions => ["(#{@query.statement}) AND (((start_date>=? and start_date<=?) or (due_date>=? and due_date<=?) or (start_date<? and due_date>?)) and start_date is not null and due_date is not null)", @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to]
                           )
      # Issues that don't have a due date but that are assigned to a version with a date
      events += Issue.find(:all, 
                           :order => "start_date, effective_date",
                           :include => [:tracker, :status, :assigned_to, :priority, :project, :fixed_version], 
                           :conditions => ["(#{@query.statement}) AND (((start_date>=? and start_date<=?) or (effective_date>=? and effective_date<=?) or (start_date<? and effective_date>?)) and start_date is not null and due_date is null and effective_date is not null)", @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to, @gantt.date_from, @gantt.date_to]
                           )
      # Versions
      events += Version.find(:all, :include => :project,
                                   :conditions => ["(#{@query.project_statement}) AND effective_date BETWEEN ? AND ?", @gantt.date_from, @gantt.date_to])
                                   
      @gantt.events = events
    end
    
    respond_to do |format|
      format.html { render :template => "issues/gantt.rhtml", :layout => !request.xhr? }
      format.png  { send_data(@gantt.to_image, :disposition => 'inline', :type => 'image/png', :filename => "#{@project.nil? ? '' : "#{@project.identifier}-" }gantt.png") } if @gantt.respond_to?('to_image')
      format.pdf  { send_data(gantt_to_pdf(@gantt, @project), :type => 'application/pdf', :filename => "#{@project.nil? ? '' : "#{@project.identifier}-" }gantt.pdf") }
    end
  end

  def calendar
    if params[:year] and params[:year].to_i > 1900
      @year = params[:year].to_i
      if params[:month] and params[:month].to_i > 0 and params[:month].to_i < 13
        @month = params[:month].to_i
      end    
    end
    @year ||= Date.today.year
    @month ||= Date.today.month
    
    @calendar = Redmine::Helpers::Calendar.new(Date.civil(@year, @month, 1), current_language, :month)
    retrieve_query
    if @query.valid?
      events = []
      events += Issue.find(:all, 
                           :include => [:tracker, :status, :assigned_to, :priority, :project], 
                           :conditions => ["(#{@query.statement}) AND ((start_date BETWEEN ? AND ?) OR (due_date BETWEEN ? AND ?))", @calendar.startdt, @calendar.enddt, @calendar.startdt, @calendar.enddt]
                           )
      events += Version.find(:all, :include => :project,
                                   :conditions => ["(#{@query.project_statement}) AND effective_date BETWEEN ? AND ?", @calendar.startdt, @calendar.enddt])
                                     
      @calendar.events = events
    end
    
    render :template => "issues/calendar", :layout => !request.xhr?
  end

  def edit
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @priorities = Enumeration.priorities
    @accounting = Enumeration.accounting_types
    @default = @issue.accounting.id
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @time_entry = TimeEntry.new

    @notes = params[:notes]
    journal = @issue.init_journal(User.current, @notes)
    # User can change issue attributes only if he has :edit permission or if a workflow transition is allowed
    if (@edit_allowed || !@allowed_statuses.empty?) && params[:issue]
      attrs = params[:issue].dup
      attrs.delete_if {|k,v| !UPDATABLE_ATTRS_ON_TRANSITION.include?(k) } unless @edit_allowed
      attrs.delete(:status_id) unless @allowed_statuses.detect {|s| s.id.to_s == attrs[:status_id].to_s}
      issue_clone = @issue.clone
      @issue.predefined_tasks = params[:issue]['predefined_tasks']
      @issue.attributes = attrs
    end

    if request.post?
      Issue.transaction do
        @time_entry = TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => Date.today)
        @time_entry.attributes = params[:time_entry]
        attachments = attach_files(@issue, params[:attachments])
        attachments.each {|a| journal.details << JournalDetail.new(:property => 'attachment', :prop_key => a.id, :value => a.filename)}

        call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => @time_entry, :journal => journal})
        unless @issue.assigned_to.nil?
          @issue.errors.add_to_base "Cannot assign to resigned resource." if employee_status == "Resigned"
        end
        if (@time_entry.hours.nil? || @time_entry.valid?) && @issue.errors.empty? && @issue.save
          # Log spend time
          if User.current.allowed_to?(:log_time, @project)
            unless @time_entry.hours.nil?
              time_log_validation
              if @total_hours <= 24 && @user_is_member && @accept_time_log && @budget_consumed == false
                @time_entry.save
              else
                flash[:error] = "Cannot log more than 24 hours per day" unless @total_hours <= 24
                flash[:error] = "You are not allowed to log time to this task." unless @accept_time_log
                flash[:error] = "User is not a member of this project." unless @user_is_member
                flash[:error] = "Please log hours in a generic non-billable task." unless @budget_consumed == false
              end
            end
            if !@time_entry.hours.nil?
              journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'hours', :value => @time_entry.hours)
              journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'activity_id', :value => @time_entry.activity_id)
              journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'spent_on', :value => @time_entry.spent_on)
              if !@issue.estimated_hours.nil?
                total_time_entry = TimeEntry.sum(:hours, :conditions => "issue_id = #{@issue.id}")
                remaining_estimate = @issue.estimated_hours - total_time_entry
                journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'remaining_estimate',
                                                     :value => remaining_estimate >= 0 ? remaining_estimate : 0)
              end
              #journal.save
            end
            if !@time_entry.hours.nil? || !journal.notes.blank?
              journal.save
            end
          end
          if !journal.new_record? && flash[:error].nil?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => @time_entry, :journal => journal})
          if update_ticket_at_mystic?
            return(update_mystic_ticket(@issue, @notes))
          else
            redirect_to(params[:back_to] || {:controller => 'issues', :action => 'show', :id => @issue})
          end
        else
          render :template => "issues/edit", :layout => !request.xhr?
        end
      end # transaction end
    end
  rescue ActiveRecord::StaleObjectError
    # Optimistic locking exception
    flash[:error] = l(:notice_locking_conflict)
    redirect_to(params[:back_to] || {:controller => 'issues', :action => 'edit', :id => @issue})
  end

  def destroy
    @hours = params[:children_todo] ? 0 : TimeEntry.sum(:hours, :conditions => ['issue_id IN (?)', @issues]).to_f
    @children = IssueRelation.count('id',
                                    :conditions => ["relation_type = 'subtasks' and issue_from_id IN (?)", @issues])
    del_subtasks = false
    if @hours > 0
      case params[:todo]
      when 'destroy'
        # nothing to do
      when 'nullify'
        TimeEntry.update_all('issue_id = NULL', ['issue_id IN (?)', @issues])
      when 'reassign'
        reassign_to = @project.issues.find_by_id(params[:reassign_to_id])
        if reassign_to.nil?
          flash.now[:error] = l(:error_issue_not_found_in_project)
          return
        else
          TimeEntry.update_all("issue_id = #{reassign_to.id}", ['issue_id IN (?)', @issues])
        end
      else
        # display the destroy form
        return
      end
    end
    if @children > 0
      @hours = 0
      case params[:children_todo]
      when 'destroy_parent_only'
        # do nothing
      when 'destroy_all'
        del_subtasks = true
      else
        # display the destroy form
        return
      end
    end
    @issues.each do |i|
      i.delete_child_issues if !i.children.blank? && del_subtasks
      i.destroy if Issue.exists?(i)
    end
    redirect_to :action => 'index', :controller => 'issues', :project_id => @project
  end
  
  private
  def custom_authorize(action = params[:action])
    allowed = User.current.allowed_to?({:controller => 'issues', :action => action}, @project)
    allowed ? true : deny_access
  end

  def filter
    @milestone_filter = 1
    @output = case params[:milestone]
              when "1"
                [1,2]
              else
                [2]
              end
  end

  def custom_find_optional_project
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
    allowed = User.current.allowed_to?({:controller => 'issues', :action => params[:action]}, @project, :global => true)
    allowed ? true : deny_access
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def employee_status
    r = @issue.assigned_to.custom_values.detect {|v| v.mgt_custom "Employee Status"}
    status = r ? r.value : ""
  end

  def display_by_billing_model
    if @project.billing_model
      if @project.billing_model.scan(/^(Fixed)/).flatten.present?
        "fixed"
      elsif @project.billing_model.scan(/^(T and M)/i).flatten.present?
        "billability"
      end
    end
  end

  def budget_computation(project_id)
      project = Project.find(project_id)
      bac_amount = project.project_contracts.all.sum(&:amount)
      contingency_amount = 0
      @actuals_to_date = 0
      @project_budget = 0

      pfrom, afrom, pto, ato = project.planned_start_date, project.actual_start_date, project.planned_end_date, project.actual_end_date
      to = (ato || pto)

      if pfrom && to
        team = project.members.project_team.all
        reporting_period = (Date.today-1.week).end_of_week
        forecast_range = get_weeks_range(pfrom, to)
        actual_range = get_weeks_range((afrom || pfrom), reporting_period)
        cost = project.monitored_cost(forecast_range, actual_range, team)
        actual_list = actual_range.collect {|r| r.first }
        cost.each do |k, v|
          if actual_list.include?(k.to_date)
            @actuals_to_date += v[:actual_cost]
          end
        end
        @project_budget = bac_amount + contingency_amount
      end
  end

  def time_log_validation
    user = User.current
    issue_is_billable = false
    @total_hours = 0.0
    @user_is_member = false
    @accept_time_log = false
    @budget_consumed = false

    @total_entries = user.time_entries.find(:all, :conditions => "spent_on = '#{@time_entry.spent_on}'")
    @total_entries.each do |v|
      @total_hours += v.hours
    end
    @total_hours += @time_entry.hours unless @time_entry.hours.nil?

    issue_is_billable = true if @issue.acctg_type == Enumeration.find_by_name('Billable').id
    if @project.project_type.scan(/^(Admin)/).flatten.present?
      if membership = @project.members.detect {|m| m.user_id == user.id}
        @user_is_member = true
        @accept_time_log = true
      end
    else
      if membership = @project.members.project_team.detect {|m| m.user_id == user.id}
        @user_is_member = true
        billable_member = membership.billable?(@time_entry.spent_on, @time_entry.spent_on)
        non_billable_member = membership.non_billable?(@time_entry.spent_on)
        shadow_member = membership.is_shadowed?(@time_entry.spent_on)
        @accept_time_log = true if ((issue_is_billable && billable_member) || (!issue_is_billable && non_billable_member) || (!issue_is_billable && shadow_member))
      end
    end

    if display_by_billing_model.eql?("fixed")
      budget_computation(@project.id)
      if (@project_budget - @actuals_to_date) < 0 && issue_is_billable
        @budget_consumed = true
      end
    end
  end

end
