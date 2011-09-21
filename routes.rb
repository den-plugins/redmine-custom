#map.connect 'subtask/create', :controller => 'subtask', :action => 'create'

map.with_options :controller => 'subtask' do |group_routes|
  group_routes.with_options :conditions => {:method => :get} do |group_views|
    group_views.connect 'subtask/create', :action => 'create'
  end
  group_routes.with_options :conditions => {:method => :post} do |group_actions|
    group_actions.connect 'subtask/create', :action => 'create'
  end
end
