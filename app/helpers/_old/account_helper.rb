module AccountHelper
  
  def show_edit_link(user)
    links = Array.new
    if User.current.admin?
      links << link_to(l(:label_edit_account), {:controller => 'users', :action => 'edit', :id => @user}, :class => 'icon icon-edit')
      links << link_to(l(:label_edit_profile), {:controller => 'resources', :action => 'edit', :resource => @user.resource.id}) unless user.resource.nil?
    end
    links.join(" | ")
  end
end
