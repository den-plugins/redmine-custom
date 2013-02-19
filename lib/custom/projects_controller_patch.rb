module Custom
  module ProjectsControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :new, :acctg_types
        alias_method_chain :create, :acctg_types
        alias_method_chain :settings, :acctg_types
        alias_method_chain :update, :acctg_types
      end
    end

    module InstanceMethods

      def new_with_acctg_types
        @issue_custom_fields = IssueCustomField.find(:all, :order => "#{CustomField.table_name}.position")
        @trackers = Tracker.sorted.all
        @project = Project.new
        @project.safe_attributes = params[:project]
        @accounting = AccountingType.all
      end

      def create_with_acctg_types
        @issue_custom_fields = IssueCustomField.find(:all, :order => "#{CustomField.table_name}.position")
        @trackers = Tracker.sorted.all
        @project = Project.new
        @project.safe_attributes = params[:project]
        @project.accounting = AccountingType.find_by_name(params[:project][:acctg_type])

        if validate_parent_id && @project.save
          @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
          # Add current user as a project member if he is not admin
          unless User.current.admin?
            r = Role.givable.find_by_id(Setting.new_project_user_role_id.to_i) || Role.givable.first
            m = Member.new(:user => User.current, :roles => [r])
            @project.members << m
          end
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_create)
              redirect_to(params[:continue] ?
                {:controller => 'projects', :action => 'new', :project => {:parent_id => @project.parent_id}.reject {|k,v| v.nil?}} :
                {:controller => 'projects', :action => 'settings', :id => @project}
              )
            }
            format.api  { render :action => 'show', :status => :created, :location => url_for(:controller => 'projects', :action => 'show', :id => @project.id) }
          end
        else
          respond_to do |format|
            format.html { render :action => 'new' }
            format.api  { render_validation_errors(@project) }
          end
        end
      end

      def settings_with_acctg_types
        @issue_custom_fields = IssueCustomField.find(:all, :order => "#{CustomField.table_name}.position")
        @issue_category ||= IssueCategory.new
        @member ||= @project.members.new
        @trackers = Tracker.sorted.all
        @wiki ||= @project.wiki
        @accounting ||= AccountingType.all
        @default = @project.accounting.name if @project.accounting
      end

      def update_with_acctg_types
        @project.accounting = AccountingType.find_by_name(params[:project][:acctg_type])
        @project.safe_attributes = params[:project]
        if validate_parent_id && @project.save
          @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_update)
              redirect_to :action => 'settings', :id => @project
            }
            format.api  { render_api_ok }
          end
        else
          respond_to do |format|
            format.html {
              settings
              render :action => 'settings'
            }
            format.api  { render_validation_errors(@project) }
          end
        end
      end

    end
  end
end