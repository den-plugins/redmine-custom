require_dependency 'application'

module AccountControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :show, :archived
    end
  end

  module InstanceMethods
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
