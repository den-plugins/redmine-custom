class MultiMembersController < MembersController

  before_filter :find_member, :except => [:new, :autocomplete_for_member_login, :destroy, :delete_members, :new_member]
  skip_filter :authorize

  def destroy
    @members = Member.find_all_by_id(params[:id] || params[:member_ids])
    @project = @members.first.project
    @members.each(&:destroy)
	respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'members', :id => @project }
      format.js { render(:update) {|page| page.replace_html "tab-content-members", :partial => 'projects/settings/members'} }
    end
  end

  def new_member
    @project = Project.find(params[:project_id])
    roles = Role.find_all_givable
    render :partial => "members/new", :locals => {:roles => roles}
  end
  
  def delete_members
    @project = Project.find(params[:project_id])
    render :partial => "members/delete"
  end

end