module RedmineHideEstimatedHours
  module Patches
    module QueryPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable
          alias_method_chain :available_columns, :patch 
          alias_method_chain :available_filters, :patch
        end
      end

      module ClassMethods
      end

      module InstanceMethods
	#see <redmine_src>/app/models/query.rb for overwritten methods

        def available_columns_with_patch
          return @available_columns if @available_columns
          @available_columns = available_columns_without_patch
          if !User.current.allowed_to?(:view_time_entries, project)
            @available_columns.delete_if { |querycolumn| querycolumn.name == :estimated_hours } #remove :estimated_hours from Query.available_columns
          end
          return @available_columns
        end

        def available_filters_with_patch
          return @available_filters if @available_filters
          @available_filters = available_filters_without_patch
          @available_filters.delete("estimated_hours") if !User.current.allowed_to?(:view_time_entries, project)          
          return @available_filters
        end

      end
    end
  end
end
