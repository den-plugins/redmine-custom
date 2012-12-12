class CustomUsersController < UsersController
  before_filter :require_admin, :except => [:check_time_entries]
  skip_before_filter :require_login, :only => [:check_time_entries]
  skip_before_filter :check_if_login_required, :only => [:check_time_entries]

  helper :sort
  include SortHelper
  helper :custom_users
  helper :custom_fields
  include CustomFieldsHelper

  def edit
    @user = User.find(params[:id])
    if request.post?
      @user.admin = params[:user][:admin] if params[:user][:admin]
      @user.login = params[:user][:login] if params[:user][:login]
      @user.password, @user.password_confirmation = params[:password], params[:password_confirmation] unless params[:password].nil? or params[:password].empty? or @user.auth_source_id
      @user.attributes = params[:user]
      # Was the account actived ? (do it before User#save clears the change)
      was_activated = (@user.status_change == [User::STATUS_REGISTERED, User::STATUS_ACTIVE])
      if @user.employee_status == "Resigned" and @user.resignation_date.blank? || @user.resignation_date.to_date >= Date.today
        @user.errors.add_to_base "Please check employment end date."
      else
        if @user.save
          if !@user.resignation_date.empty? && !@user.resignation_date.nil?
            if @user.resignation_date.to_date < Date.today
              employee_status_field_id = CustomField.find_by_name("Employee Status")
              @user.custom_values.find_by_custom_field_id(employee_status_field_id).update_attribute :value, "Resigned"
            end
          end
          Mailer.deliver_account_activated(@user) if was_activated
          flash[:notice] = l(:notice_successful_update)
          # Give a string to redirect_to otherwise it would use status param as the response code
          redirect_to(url_for(:controller => 'users', :action => 'list', :status => params[:status], :page => params[:page]))
        end
      end
    end
    @auth_sources = AuthSource.find(:all)
    @roles = Role.find_all_givable
    @projects = Project.active.find(:all, :order => 'lft')
    @membership ||= Member.new
    @memberships = @user.memberships
    @skills = Skill.find(:all)
  end

  def check_time_entries
    @complete = false
    if params[:username]
      username = params[:username]
      start_date = (Date.today - 7.days).beginning_of_week
      end_date = (Date.today - 7.days).end_of_week
      @resource = User.find_by_login(username)
      @time_entries_total = @resource.time_entries.find(:all, :conditions => ["spent_on >= ? AND spent_on <= ?", start_date, end_date]).sum(&:hours)
      @complete = @time_entries_total < 40 ? false : true
    end
    render :json => { :complete => @complete }.to_json
  end
end
