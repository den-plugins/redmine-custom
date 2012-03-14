#*****************************************************************************
# controller that overrides some methods from issuescontoller
#
#*****************************************************************************

class CustomIssuesController < IssuesController

  skip_before_filter :authorize, :only => [:new, :find_project, :edit, :destroy]
  before_filter :custom_authorize, :only => [:new, :find_project, :edit, :destroy]
  
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

      if @issue.save
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

        if (@time_entry.hours.nil? || @time_entry.valid?) && @issue.save
          # Log spend time
          if User.current.allowed_to?(:log_time, @project)
            @time_entry.save
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
          if !journal.new_record?
            # Only send notification if something was actually changed
            flash[:notice] = l(:notice_successful_update)
          end
          call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => @time_entry, :journal => journal})
          if update_ticket_at_mystic?
            return(update_mystic_ticket(@issue, @notes))
          else
            redirect_to(params[:back_to] || {:controller => 'issues', :action => 'show', :id => @issue})
          end
        end
      end # transaction end
    end
  render :template => "issues/edit", :layout => !request.xhr?
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
end
