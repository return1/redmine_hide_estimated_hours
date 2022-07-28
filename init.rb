require 'redmine'

require 'query_patch'
require 'journal_patch'
require 'pdf_patch'

Redmine::Plugin.register :redmine_hide_estimated_hours do
  name 'Hide estimated hours'
  author 'Dominique Lederer (return1)'
  description 'This Redmine plugin reuses the "view_time_entries" permission to hide the estimated hours field'
  version '1.0.15'
  url 'https://github.com/return1/redmine_hide_estimated_hours'
  author_url 'http://return1.at/'

  requires_redmine :version => '4.2'

end
