require_relative '../test_helper'
require 'open3'

class HideEstimatedHoursTest < Redmine::IntegrationTest
  PASSWORD = 'SmokeTest2026!'.freeze
  ESTIMATE_COLUMNS = %w(estimated_hours total_estimated_hours estimated_remaining_hours).freeze

  setup do
    @issue = issues(:issues_001)
    @version = versions(:versions_003)
    @allowed = users(:users_002)
    @denied = users(:users_003)
    @admin = users(:users_001)
    [@allowed, @denied, @admin].each do |user|
      user.update!(:password => PASSWORD, :password_confirmation => PASSWORD)
    end
    allowed_role = roles(:roles_001)
    denied_role = allowed_role.dup
    denied_role.name = 'Estimate visibility test'
    denied_role.permissions = allowed_role.permissions - [:view_time_entries]
    denied_role.save!
    @issue.project.members.find_by!(:user_id => @denied.id).update!(:roles => [denied_role])
    @issue.update!(:fixed_version => @version, :estimated_hours => 9.25)
    @issue.init_journal(@allowed, 'Estimate visibility check')
    @issue.update!(:estimated_hours => 13.25)
    @project = @issue.project.identifier
  end

  test 'issue show page' do
    each_user do |user, count|
      get "/issues/#{@issue.id}"
      assert_response :success
      assert_select '.estimated-hours', count
      assert_select '#history li', :text => /Estimated time/, :count => count
    end
  end

  test 'issue edit and bulk edit forms' do
    each_user do |user, count|
      get "/issues/#{@issue.id}/edit"
      assert_response :success
      assert_select 'input#issue_estimated_hours', count

      get '/issues/bulk_edit', :params => {:ids => [@issue.id]}
      assert_response :success
      assert_select 'input#issue_estimated_hours', count
    end
  end

  test 'query filters and column options' do
    each_user do |user, count|
      get "/projects/#{@project}/issues", :params => {:set_filter => '1'}
      assert_response :success
      filters = JSON.parse(response.body[/var availableFilters = (.*?);/, 1])
      assert_equal count == 1, filters.key?('estimated_hours')
      ESTIMATE_COLUMNS.each do |column|
        assert_select "select#available_c option[value='#{column}']", count
      end
    end
  end

  test 'estimate columns, filter and sort passed via URL params' do
    params = {
      :set_filter => '1',
      :f => ['estimated_hours'], :op => {'estimated_hours' => '>='}, :v => {'estimated_hours' => ['1']},
      :c => %w(subject) + ESTIMATE_COLUMNS,
      :sort => 'estimated_hours:desc'
    }
    each_user do |user, count|
      get "/projects/#{@project}/issues", :params => params
      assert_response :success
      ESTIMATE_COLUMNS.each do |column|
        if count == 1
          assert_select "table.issues td.#{column}", :minimum => 1
        else
          assert_select "table.issues td.#{column}", 0
        end
      end

      get "/projects/#{@project}/issues.csv", :params => params
      assert_response :success
      assert_equal count == 1, response.body.include?('13.25')
    end
  end

  test 'issue API hides estimates' do
    each_user do |user, count|
      headers = {'X-Redmine-API-Key' => user.api_key}

      get "/issues/#{@issue.id}.json", :headers => headers
      assert_response :success
      assert_estimate JSON.parse(response.body).fetch('issue'), count

      get '/issues.json', :params => {:project_id => @project}, :headers => headers
      assert_response :success
      listed = JSON.parse(response.body).fetch('issues').find {|row| row['id'] == @issue.id}
      assert_estimate listed, count
    end
  end

  test 'issue API journals hide estimate changes' do
    each_user do |user, count|
      get "/issues/#{@issue.id}.json", :params => {:include => 'journals'},
          :headers => {'X-Redmine-API-Key' => user.api_key}
      assert_response :success
      details = JSON.parse(response.body).dig('issue', 'journals').flat_map {|j| j['details']}
      assert_equal count, details.count {|d| d['name'] == 'estimated_hours'}
    end
  end

  test 'admin without project role sees estimates' do
    with_settings :rest_api_enabled => '1', :default_language => 'en' do
      log_in(@admin)
      get "/issues/#{@issue.id}"
      assert_response :success
      assert_select '.estimated-hours', 1
      assert_select '#history li', :text => /Estimated time/, :count => 1

      get "/projects/#{@project}/issues", :params => {:set_filter => '1'}
      ESTIMATE_COLUMNS.each {|column| assert_select "select#available_c option[value='#{column}']", 1}

      get "/issues/#{@issue.id}.json", :params => {:include => 'journals'},
          :headers => {'X-Redmine-API-Key' => @admin.api_key}
      details = JSON.parse(response.body).dig('issue', 'journals').flat_map {|j| j['details']}
      assert_equal 1, details.count {|d| d['name'] == 'estimated_hours'}
    end
  end

  test 'issue PDF export' do
    skip 'pdftotext not installed' unless system('which pdftotext', :out => File::NULL, :err => File::NULL)
    each_user do |user, count|
      get "/issues/#{@issue.id}.pdf"
      assert_response :success
      assert_equal 'application/pdf', response.media_type
      pdf_text, status = Open3.capture2('pdftotext', '-', '-', :stdin_data => response.body, :binmode => true)
      assert status.success?, 'pdftotext could not extract the issue PDF text'
      assert_equal count == 1, pdf_text.include?('Estimated time:')
    end
  end

  test 'version time tracking summary' do
    each_user do |user, count|
      get "/versions/#{@version.id}"
      assert_response :success
      assert_select '#version-summary fieldset.time-tracking', count
    end
  end

  private

  # Yields each user with the expected number of estimate elements (1 visible, 0 hidden).
  def each_user
    with_settings :rest_api_enabled => '1', :default_language => 'en' do
      [[@allowed, 1], [@denied, 0]].each do |user, count|
        log_in(user)
        yield user, count
      end
    end
  end

  def log_in(user)
    reset!
    log_user(user.login, PASSWORD)
  end

  def assert_estimate(issue, count)
    %w(estimated_hours total_estimated_hours).each do |field|
      if count == 1
        assert_equal 13.25, issue.fetch(field)
      else
        refute issue.key?(field)
      end
    end
  end
end
