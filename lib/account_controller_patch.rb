require_dependency 'application'

module AccountControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :show, :archived
      alias_method_chain :password_authentication, :archived
    end
  end

  module InstanceMethods
    def password_authentication_with_archived
      user = User.try_to_login_with_custom_error_message(params[:username], params[:password])
      if user.nil?
        # Invalid credentials
        flash.now[:error] = l(:notice_account_invalid_creditentials)
      elsif user.locked? or user.archived?
        flash.now[:error] = l(:notice_account_not_active)
      elsif user.new_record?
        # Onthefly creation failed, display the registration form to fill/fix attributes
        @user = user
        session[:auth_source_registration] = {:login => user.login, :auth_source_id => user.auth_source_id }
        render :action => 'register'
      else
        # Valid user
        successful_authentication(user)
      end
    end
    
    def show_with_archived
      @user = User.active_and_archived.find(params[:id])
      @custom_values = @user.custom_values
      # show only public projects and private projects that the logged in user is also a member of
      @memberships = @user.memberships.select do |membership|
        membership.project.is_public? || (User.current.member_of?(membership.project))
      end
      events = Redmine::Activity::Fetcher.new(User.current, :author => @user).events(nil, nil, :limit => 10)
      @events_by_day = events.group_by(&:event_date)
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
