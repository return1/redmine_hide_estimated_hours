require_dependency 'journal'


module JournalPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method :visible_details_without_patch, :visible_details
      alias_method :visible_details, :visible_details_with_patch
    end
  end

  module InstanceMethods
    #see <redmine_src>/app/models/journal.rb for overwritten methods

    # Returns journal details that are visible to user
    def visible_details_with_patch(user=User.current)
      details.select do |detail|
        if detail.property == 'cf'
          detail.custom_field && detail.custom_field.visible_by?(project, user)
        elsif detail.property == 'relation'
          Issue.find_by_id(detail.value || detail.old_value).try(:visible?, user)
        # removing estimated time in this elsif
        elsif detail.property == 'attr' && detail.prop_key == 'estimated_hours' && !user.allowed_to?(:view_time_entries, project)
          false
        else
          true
        end
      end
    end

  end
end

Journal.send(:include, JournalPatch)
