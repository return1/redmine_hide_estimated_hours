require 'redmine'

Redmine::Plugin.register :redmine_hide_estimated_hours do
  name 'Hide estimated hours'
  author 'Dominique Lederer (return1)'
  description 'This Redmine plugin reuses the "view_time_entries" permission to hide the estimated hours field'
  version '1.0.1'
  url 'http://return1.at/'
  author_url 'http://return1.at/'

  requires_redmine :version_or_higher => '1.4.0'

end

require 'dispatcher'
Dispatcher.to_prepare :redmine_hide_estimated_hours do
  require_dependency 'query'
  unless Query.included_modules.include? RedmineHideEstimatedHours::Patches::QueryPatch
    Query.send(:include, RedmineHideEstimatedHours::Patches::QueryPatch)
  end
end

require 'redmine_hide_estimated_hours/hooks/helper_issues_show_detail_after_setting_hook'
