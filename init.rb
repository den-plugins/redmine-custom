require 'redmine'

# Patches to the Redmine core
require 'custom_issue_patch'
require 'custom_issue_relation_patch'

Dispatcher.to_prepare do
  Issue.send(:include, Custom::IssuePatch)
  IssueRelation.send(:include, Custom::IssueRelationPatch)
end

Redmine::Plugin.register :redmine_custom do
  name 'Redmine Custom Plugin'
  author 'Author'
  description "Redmine Core Changes"
  version '1.0.0'
end

