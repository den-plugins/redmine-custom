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

map.connect 'stories/:project_id/issues', :controller => 'custom_issues', :action => 'index'
map.connect 'projects/:project_id/issues', :controller => 'custom_issues', :action => 'index'
map.connect 'stories/:project_id/issues/new/', :controller => 'custom_issues', :action => 'new'
map.connect 'projects/:project_id/issues/new/', :controller => 'custom_issues', :action => 'new'
map.connect 'admin/holidays', :controller => 'holidays'
map.connect 'projects/:project_id/issues/calendar', :controller => 'custom_issues', :action => 'calendar'
map.connect 'projects/:project_id/issues/gantt', :controller => 'custom_issues', :action => 'gantt'
map.with_options :controller => 'custom_issues' do |issues_routes|
   issues_routes.with_options :conditions => {:method => :post} do |issues_actions|
     issues_actions.connect 'issues/:id/:action', :action => /edit/, :id => /\d+/
   end
end

map.connect 'projects/:id/members/new', :controller => 'multi_members', :action => 'new'
