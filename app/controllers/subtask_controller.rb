class SubtaskController < IssuesController
  before_filter :find_project
  before_filter :find_optional_project
  skip_filter :authorize

   

  
  def create
    @tracker_id = params[:issue] ? (params[:issue][:tracker_id].to_i) : 4
    @project = Project.find(params[:project_id] ? params[:project_id] : params[:issue][:project_id])
    @issue = Issue.new
    @issue.copy_from(params[:copy_from]) if params[:copy_from]
    @issue.project = @project
    @mode = 'subtask'
    
    # Specify on case-basis the viable tracker options for the subtask
    @tracker_list = []
    @project.trackers.each do |x|
      case
      when params[:parent_tracker_id].to_i == 1 # Bug
        @tracker_list << [x.name,x.id] if x.id == 1
      when params[:parent_tracker_id].to_i == 2 # Feature
        @tracker_list << [x.name,x.id] if x.id == 2 || 4
      else
        @tracker_list << [x.name,x.id] if x.id != 2
      end
    end

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

    if request.get? || request.xhr?
      @issue.start_date ||= Date.today
    else
      requested_status = IssueStatus.find_by_id(params[:issue][:status_id])
      # Check that the user is allowed to apply the requested status
      @issue.status = (@allowed_statuses.include? requested_status) ? requested_status : default_status

      if @issue.save
        @relation = IssueRelation.new()
        @relation.issue_from = Issue.find(params[:issue_from_id])
        @relation.relation_type = params[:relation_type]
        @relation.issue_to = @issue     
        @relation.save
        attach_files(@issue, params[:attachments])
        flash[:notice] = l(:notice_successful_create)
        call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
        redirect_to(params[:continue] ? { :action => 'create', :tracker_id => @issue.tracker } :
                                        {  :controller => 'issues' ,:action => 'show', :id => @relation.issue_from })
        return
      end		
    end	
    @priorities = Enumeration.priorities
    @accounting = Enumeration.accounting_types
    @default = !@project.accounting.nil? ? @project.accounting.id : Enumeration.accounting_types.default.id if Enumeration.accounting_types
    render :layout => !request.xhr? 
  end

private
  def find_optional_project
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
    allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
    allowed ? true : deny_access
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
end

