require 'redmine'

# Patches to the Redmine core
require 'custom_issue_patch'

Dispatcher.to_prepare do
  Issue.send(:include, Custom::IssuePatch)
end

Redmine::Plugin.register :redmine_custom do
  name 'Redmine Custom Plugin'
  author 'Author'
  description "Redmine Core Changes"
  version '1.0.0'
end

