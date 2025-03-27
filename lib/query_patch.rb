require_dependency 'query'
require_dependency 'issue_query'

module QueryPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      alias_method :available_filters_without_patch, :available_filters
      alias_method :available_filters, :available_filters_with_patch
    end
  end

  module InstanceMethods
    #see <redmine_src>/app/models/query.rb for overwritten methods

    def available_filters_with_patch
      return @available_filters if @available_filters
      @available_filters = available_filters_without_patch
      @available_filters.delete("estimated_hours") if (!User.current.allowed_to?(:view_time_entries, project) and !User.current.admin)
      return @available_filters
    end

  end
end

module IssueQueryPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      alias_method :available_columns_without_patch, :available_columns
      alias_method :available_columns, :available_columns_with_patch
    end
  end

  module InstanceMethods
    #see <redmine_src>/app/models/issue_query.rb for overwritten methods

    def available_columns_with_patch
      return @available_columns if @available_columns
      @available_columns = available_columns_without_patch
      if (!User.current.allowed_to?(:view_time_entries, project) and !User.current.admin)
        @available_columns.delete_if { |querycolumn| querycolumn.name == :estimated_hours } #remove :estimated_hours from Query.available_columns
        @available_columns.delete_if { |querycolumn| querycolumn.name == :total_estimated_hours } #remove :total_estimated_hours from Query.available_columns
        @available_columns.delete_if { |querycolumn| querycolumn.name == :estimated_remaining_hours } #remove :estimated_remaining_hours from Query.available_columns
      end
      return @available_columns
    end

  end
end

Query.send(:include, QueryPatch)
IssueQuery.send(:include, IssueQueryPatch)
