class MultiMembersController < MembersController

  before_filter :find_member, :except => [:new, :autocomplete_for_member_login, :destroy, :delete_members, :new_member]
  skip_filter :authorize

  def destroy
    @members = Member.find_all_by_id(params[:id] || params[:member_ids])
    @project = @members.first.project
    @errors = ""
    @members.each do |member|
      @errors = member.errors.full_messages if !member.destroy and @errors.blank?
    end
    if @errors.blank?
      @errors = nil
      @notices = l(:notice_successful_delete)
    end
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

  def new
    members = []
    resigned_members = []
    @errors = ""

    if params[:member] && request.post?
      attrs = params[:member].dup
      if (user_ids = attrs.delete(:user_ids))
        user_ids.each do |user_id|
          unless User.find_by_login(attrs[:user_login]).employee_status == 'Resigned'
            members << Member.new(attrs.merge(:user_id => user_id))
          else
            resigned_members << name(attrs[:user_login], 'login')
            attrs[:user_login] = ""
            members << Member.new(attrs.merge(:user_id => user_id))
          end
          members.each { |member| if User.find(member.user_id).employee_status == 'Resigned'
                                    members.delete(member)
                                    resigned_members << name(member.user_id, 'id')
                                  end}
        end
      else
        if User.find_by_login(attrs[:user_login]).employee_status == 'Resigned'
          resigned_members << name(attrs[:user_login], 'login')
          attrs[:user_login] = ""
        end
        members << Member.new(attrs)
      end
      @errors = resigned_members.empty? ? nil : "Already resigned: #{resigned_members.join(', ')}"
      @project.members << members
    end
    respond_to do |format|
      format.html { redirect_to :controller => 'projects', :action => 'settings', :tab => 'members', :id => @project }
      format.js {
        render(:update) {|page|
          page.replace_html "tab-content-members", :partial => 'projects/settings/members'
          members.each {|member| page.visual_effect(:highlight, "member-#{member.id}") }
        }
      }
    end
  end

  private
  def name(user_identifier, type)
    if type == "id"
      lastname = User.find(user_identifier).lastname
      firstname = User.find(user_identifier).firstname
    else
      lastname = User.find_by_login(user_identifier).lastname
      firstname = User.find_by_login(user_identifier).firstname
    end
    "#{firstname} #{lastname}"
  end

end
