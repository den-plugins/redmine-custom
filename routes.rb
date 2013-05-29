#map.connect 'subtask/create', :controller => 'subtask', :action => 'create'

map.with_options :controller => 'subtask' do |group_routes|
  group_routes.with_options :conditions => {:method => :get} do |group_views|
    group_views.connect 'subtask/create', :action => 'create'
  end
  group_routes.with_options :conditions => {:method => :post} do |group_actions|
    group_actions.connect 'subtask/create', :action => 'create'
  end
end

map.with_options :controller => 'custom_users' do |users|
  users.with_options :conditions => {:method => :get} do |user_views|
    user_views.connect 'users/:id/edit/:tab', :action => 'edit', :tab => nil
  end
  users.with_options :conditions => {:method => :post} do |user_actions|
    user_actions.connect 'users/:id/edit', :action => 'edit'
  end
end

map.with_options :controller => 'issues' do |issues_routes|
  issues_routes.with_options :conditions => {:method => :get} do |issues_views|
    issues_views.connect 'issues', :action => 'index'
    issues_views.connect 'issues.:format', :action => 'index'
    issues_views.connect 'projects/:project_id/issues', :action => 'index'
    issues_views.connect 'projects/:project_id/issues.:format', :action => 'index'
    issues_views.connect 'projects/:project_id/issues/:copy_from/copy', :action => 'new'
    issues_views.connect 'issues/:id/edit', :action => 'edit', :id => /\d+/
    issues_views.connect 'issues/:id/move', :action => 'move', :id => /\d+/
  end
  issues_routes.with_options :conditions => {:method => :post} do |issues_actions|
    issues_actions.connect 'projects/:project_id/issues/:copy_from/copy', :action => 'new'
    issues_actions.connect 'issues/:id/quoted', :action => 'reply', :id => /\d+/
    issues_actions.connect 'issues/:id/:action', :action => /move/, :id => /\d+/
  end
  issues_routes.connect 'issues/:action'
end

map.connect 'stories/:project_id/issues/new/', :controller => 'custom_issues', :action => 'new'
map.connect 'projects/:project_id/issues/new/', :controller => 'custom_issues', :action => 'new'
map.connect 'issues/:id/', :controller => 'custom_issues', :action => 'show'
map.connect 'issues/show/:id', :controller => 'custom_issues', :action => 'show'
map.connect 'admin/holidays', :controller => 'holidays'
map.connect 'projects/:project_id/issues/calendar', :controller => 'custom_issues', :action => 'calendar'
map.connect 'projects/:project_id/issues/gantt', :controller => 'custom_issues', :action => 'gantt'
map.with_options :controller => 'custom_issues' do |issues_routes|
  issues_routes.with_options :conditions => {:method => :get} do |issues_views|
    issues_views.connect 'issues/:id.:format', :action => 'show', :id => /\d+/
  end
   issues_routes.with_options :conditions => {:method => :post} do |issues_actions|
     issues_actions.connect 'issues/:id/:action', :action => /edit|destroy/, :id => /\d+/
   end
end

map.connect 'users/check_time_entries', :controller => 'custom_users', :action => 'check_time_entries'

map.connect 'projects/:id/members/new', :controller => 'multi_members', :action => 'new'

map.connect 'holidays/save_holidays', :controller => 'holidays', :action => 'save_holidays'
map.connect 'holidays/update_holidays', :controller => 'holidays', :action => 'update_holidays'
