module RedmineHideEstimatedHours
  module Hooks
    class HelperIssuesShowDetailAfterSettingHook < Redmine::Hook::ViewListener
      def helper_issues_show_detail_after_setting(context = { })
        # setting the value to an empty string causes redmine to fake a deleted entry
        if context[:detail].prop_key == 'estimated_hours' && !User.current.allowed_to?(:view_time_entries, context[:project])
          context[:detail].value = nil
          context[:detail].old_value = nil
        end
        ''
      end
    end
  end
end
