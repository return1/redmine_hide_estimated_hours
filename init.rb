require 'redmine'

require File.dirname(__FILE__) + '/lib/query_patch'
require File.dirname(__FILE__) + '/lib/journal_patch'
require File.dirname(__FILE__) + '/lib/pdf_patch'

Redmine::Plugin.register :redmine_hide_estimated_hours do
  name 'Hide estimated hours'
  author 'Dominique Lederer (return1)'
  description 'This Redmine plugin reuses the "view_time_entries" permission to hide the estimated hours field'
  version '1.0.18'
  url 'https://github.com/return1/redmine_hide_estimated_hours'
  author_url 'http://return1.at/'

  requires_redmine :version => '5.1'

end
