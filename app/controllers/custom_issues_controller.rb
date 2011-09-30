#*****************************************************************************
# controller that overrides some methods from issuescontoller
#
#*****************************************************************************

class CustomIssuesController < IssuesController

  skip_before_filter :authorize, :only => [:new]
  before_filter :custom_authorize, :only => [:new]
  
  
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
                                        (params[:back_to] || { :action => 'show', :id => @issue }))
        return
      end
    end	
    @priorities = Enumeration.priorities
    @accounting = Enumeration.accounting_types
    @default = !@project.accounting.nil? ? @project.accounting.id : Enumeration.accounting_types.default.id if Enumeration.accounting_types
    render :template => 'issues/new', :layout => !request.xhr?
  end
  
  private
  def custom_authorize(action = params[:action])
    allowed = User.current.allowed_to?({:controller => 'issues', :action => action}, @project)
    allowed ? true : deny_access
  end
end
