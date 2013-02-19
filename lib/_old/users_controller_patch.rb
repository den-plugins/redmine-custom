require_dependency 'users_controller'

module UsersControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :destroy_membership, :flash_error
    end
  end

  module InstanceMethods
    def destroy_membership_with_flash_error
      @user = User.find(params[:id])
      member = Member.find(params[:membership_id])
      if request.post?
        member.destroy ? (flash[:notice] = l(:notice_successful_delete)) : (flash[:error] = member.errors.full_messages)
      end
      redirect_to :action => 'edit', :id => @user, :tab => 'memberships'
    end
  end
end
