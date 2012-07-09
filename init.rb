require 'redmine'
require 'dispatcher'

# Patches to the Redmine core
require 'remaining_effort_entry'
require 'custom_issue_patch'
require 'custom_issue_relation_patch'
require 'custom_version_patch'
require 'issues_controller_patch'
require 'custom_member_patch'
require 'custom_user_patch'
require 'custom_project_patch'
require 'custom_value_patch'
require 'custom_time_entry_patch'
require 'custom_journal_detail_patch'
require 'custom_journal_patch'
require 'account_controller_patch'
require 'delayed/scheduled_job'

Dispatcher.to_prepare do
  Issue.send(:include, Custom::IssuePatch)
  CustomValue.send(:include, Custom::ValuePatch)
  IssueRelation.send(:include, Custom::IssueRelationPatch)
  Version.send(:include, Custom::VersionPatch)
  IssuesController.send(:include, IssuesControllerPatch)
  Member.send(:include, Custom::MemberPatch)
  User.send(:include, Custom::UserPatch)
  Project.send(:include, Custom::ProjectPatch)
  TimeEntry.send(:include, Custom::TimeEntryPatch)
  UsersController.send(:include, Custom::UsersControllerPatch)
  AccountController.send(:include,  AccountControllerPatch)
  Journal.send(:include, Custom::JournalPatch)
  JournalDetail.send(:include, Custom::JournalDetailPatch)
end

#config.action_controller.session = { :session_key => "_myapp_session", :secret => '0f89835c91cb46aa8f6e35dad968a820a7a3904a'}

Redmine::Plugin.register :redmine_custom do
  name 'Redmine Custom Plugin'
  author 'Author'
  description "Redmine Core Changes"
  version '1.0.0'
end

