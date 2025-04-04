require_dependency 'redmine/export/pdf'
require_dependency 'redmine/export/pdf/issues_pdf_helper'

module PdfPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method :issue_to_pdf_without_patch, :issue_to_pdf
      alias_method :issue_to_pdf, :issue_to_pdf_with_patch
    end
  end

  module InstanceMethods
    #see <redmine_src>/lib/redmine/export/pdf/issues_pdf_helper.rb for overwritten methods

    def issue_to_pdf_with_patch(issue, assoc={})
      pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language)
      pdf.set_title("#{issue.project} - #{issue.tracker} ##{issue.id}")
      pdf.alias_nb_pages
      pdf.footer_date = format_date(User.current.today)
      pdf.add_page
      pdf.SetFontStyle('B', 11)
      buf = "#{issue.project} - #{issue.tracker} ##{issue.id}"
      pdf.RDMMultiCell(190, 5, buf)
      pdf.SetFontStyle('', 8)
      base_x = pdf.get_x
      i = 1
      issue.ancestors.visible.each do |ancestor|
        pdf.set_x(base_x + i)
        buf = "#{ancestor.tracker} # #{ancestor.id} (#{ancestor.status}): #{ancestor.subject}"
        pdf.RDMMultiCell(190 - i, 5, buf)
        i += 1 if i < 35
      end
      pdf.SetFontStyle('B', 11)
      pdf.RDMMultiCell(190 - i, 5, issue.subject.to_s)
      pdf.SetFontStyle('', 8)
      pdf.RDMMultiCell(190, 5, "#{format_time(issue.created_on)} - #{issue.author}")
      pdf.ln

      left = []
      left << [l(:field_status), issue.status]
      left << [l(:field_priority), issue.priority]
      left << [l(:field_assigned_to), issue.assigned_to] unless issue.disabled_core_fields.include?('assigned_to_id')
      left << [l(:field_category), issue.category] unless issue.disabled_core_fields.include?('category_id')
      left << [l(:field_fixed_version), issue.fixed_version] unless issue.disabled_core_fields.include?('fixed_version_id')

      right = []
      right << [l(:field_start_date), format_date(issue.start_date)] unless issue.disabled_core_fields.include?('start_date')
      right << [l(:field_due_date), format_date(issue.due_date)] unless issue.disabled_core_fields.include?('due_date')
      right << [l(:field_done_ratio), "#{issue.done_ratio}%"] unless issue.disabled_core_fields.include?('done_ratio')
      right << [l(:field_estimated_hours), l_hours(issue.estimated_hours)] unless issue.disabled_core_fields.include?('estimated_hours') || !User.current.allowed_to?(:view_time_entries, issue.project)
      right << [l(:label_spent_time), l_hours(issue.total_spent_hours)] if User.current.allowed_to?(:view_time_entries, issue.project)

      rows = [left.size, right.size].max
      left  << nil while left.size  < rows
      right << nil while right.size < rows

      custom_field_values = issue.visible_custom_field_values.reject {|value| value.custom_field.full_width_layout?}
      half = (custom_field_values.size / 2.0).ceil
      custom_field_values.each_with_index do |custom_value, i|
        (i < half ? left : right) << [custom_value.custom_field.name, show_value(custom_value, false)]
      end

      if pdf.get_rtl
        border_first_top = 'RT'
        border_last_top  = 'LT'
        border_first = 'R'
        border_last  = 'L'
      else
        border_first_top = 'LT'
        border_last_top  = 'RT'
        border_first = 'L'
        border_last  = 'R'
      end

      rows = [left.size, right.size].max
      rows.times do |i|
        heights = []
        pdf.SetFontStyle('B', 9)
        item = left[i]
        heights << pdf.get_string_height(35, item ? "#{item.first}:" : "")
        item = right[i]
        heights << pdf.get_string_height(35, item ? "#{item.first}:" : "")
        pdf.SetFontStyle('', 9)
        item = left[i]
        heights << pdf.get_string_height(60, item ? item.last.to_s  : "")
        item = right[i]
        heights << pdf.get_string_height(60, item ? item.last.to_s  : "")
        height = heights.max

        item = left[i]
        pdf.SetFontStyle('B', 9)
        pdf.RDMMultiCell(35, height, item ? "#{item.first}:" : "",
                         (i == 0 ? border_first_top : border_first), '', 0, 0)
        pdf.SetFontStyle('', 9)
        pdf.RDMMultiCell(60, height, item ? item.last.to_s : "",
                         (i == 0 ? border_last_top : border_last), '', 0, 0)

        item = right[i]
        pdf.SetFontStyle('B', 9)
        pdf.RDMMultiCell(35, height, item ? "#{item.first}:" : "",
                         (i == 0 ? border_first_top : border_first), '', 0, 0)
        pdf.SetFontStyle('', 9)
        pdf.RDMMultiCell(60, height, item ? item.last.to_s : "",
                         (i == 0 ? border_last_top : border_last), '', 0, 2)

        pdf.set_x(base_x)
      end

      pdf.SetFontStyle('B', 9)
      pdf.RDMCell(35 + 155, 5, l(:field_description), "LRT", 1)
      pdf.SetFontStyle('', 9)

      # Set resize image scale
      pdf.set_image_scale(1.6)
      text = pdf_format_text(issue, :description)
      pdf.RDMwriteFormattedCell(35+155, 5, '', '', text, issue.attachments, "LRB")

      custom_field_values = issue.visible_custom_field_values.select {|value| value.custom_field.full_width_layout?}
      custom_field_values.each do |value|
        is_html = value.custom_field.full_text_formatting?
        text = show_value(value, is_html)
        next if text.blank?

        pdf.SetFontStyle('B', 9)
        pdf.RDMCell(35+155, 5, value.custom_field.name, "LRT", 1)
        pdf.SetFontStyle('', 9)
        if is_html
          pdf.RDMwriteFormattedCell(35+155, 5, '', '', text, issue.attachments, "LRB")
        else
          pdf.RDMwriteHTMLCell(35+155, 5, '', '', text, issue.attachments, "LRB")
        end
      end

      unless issue.leaf?
        truncate_length = (!is_cjk? ? 90 : 65)
        pdf.SetFontStyle('B', 9)
        pdf.RDMCell(35+155, 5, l(:label_subtask_plural) + ":", "LTR")
        pdf.ln
        issue_list(issue.descendants.visible.sort_by(&:lft)) do |child, level|
          buf = "#{child.tracker} # #{child.id}: #{child.subject}".
            truncate(truncate_length)
          level = 10 if level >= 10
          pdf.SetFontStyle('', 8)
          pdf.RDMCell(35 + 135, 5, (level >=1 ? "  " * level : "") + buf, border_first)
          pdf.SetFontStyle('B', 8)
          pdf.RDMCell(20, 5, child.status.to_s, border_last)
          pdf.ln
        end
      end

      relations = issue.relations.select {|r| r.other_issue(issue).visible?}
      unless relations.empty?
        truncate_length = (!is_cjk? ? 80 : 60)
        pdf.SetFontStyle('B', 9)
        pdf.RDMCell(35 + 155, 5, l(:label_related_issues) + ":", "LTR")
        pdf.ln
        relations.each do |relation|
          buf = relation.to_s(issue) do |other|
            text = ""
            if Setting.cross_project_issue_relations?
              text += "#{relation.other_issue(issue).project} - "
            end
            text += "#{other.tracker} ##{other.id}: #{other.subject}"
            text
          end
          buf = buf.truncate(truncate_length)
          pdf.SetFontStyle('', 8)
          pdf.RDMCell(35+155-60, 5, buf, border_first)
          pdf.SetFontStyle('B', 8)
          pdf.RDMCell(20, 5, relation.other_issue(issue).status.to_s, "")
          pdf.RDMCell(20, 5, format_date(relation.other_issue(issue).start_date), "")
          pdf.RDMCell(20, 5, format_date(relation.other_issue(issue).due_date), border_last)
          pdf.ln
        end
      end
      pdf.RDMCell(190, 5, "", "T")
      pdf.ln

      if issue.changesets.any? &&
        User.current.allowed_to?(:view_changesets, issue.project)
        pdf.SetFontStyle('B', 9)
        pdf.RDMCell(190, 5, l(:label_associated_revisions), "B")
        pdf.ln
        issue.changesets.each do |changeset|
          pdf.SetFontStyle('B', 8)
          csstr  = "#{l(:label_revision)} #{changeset.format_identifier} - "
          csstr += format_time(changeset.committed_on) + " - " + changeset.author.to_s
          pdf.RDMCell(190, 5, csstr)
          pdf.ln
          unless changeset.comments.blank?
            pdf.SetFontStyle('', 8)
            pdf.RDMwriteHTMLCell(
              190, 5, '', '',
              changeset.comments.to_s, issue.attachments, ""
            )
          end
          pdf.ln
        end
      end

      if assoc[:journals].present?
        pdf.SetFontStyle('B', 9)
        pdf.RDMCell(190, 5, l(:label_history), "B")
        pdf.ln
        assoc[:journals].each do |journal|
          pdf.SetFontStyle('B', 8)
          title = "##{journal.indice} - #{format_time(journal.created_on)} - #{journal.user}"
          title += " (#{l(:field_private_notes)})" if journal.private_notes?
          pdf.RDMCell(190, 5, title)
          pdf.ln
          pdf.SetFontStyle('I', 8)
          details_to_strings(journal.visible_details, true).each do |string|
            pdf.RDMMultiCell(190, 5, "- " + string)
          end
          if journal.notes?
            pdf.ln unless journal.details.empty?
            pdf.SetFontStyle('', 8)
            text = pdf_format_text(journal, :notes)
            pdf.RDMwriteFormattedCell(190, 5, '', '', text, issue.attachments, "")
          end
          pdf.ln
        end
      end

      if issue.attachments.any?
        pdf.SetFontStyle('B', 9)
        pdf.RDMCell(190, 5, l(:label_attachment_plural), "B")
        pdf.ln
        issue.attachments.each do |attachment|
          pdf.SetFontStyle('', 8)
          pdf.RDMCell(80, 5, attachment.filename)
          pdf.RDMCell(20, 5, number_to_human_size(attachment.filesize), 0, 0, "R")
          pdf.RDMCell(25, 5, format_date(attachment.created_on), 0, 0, "R")
          pdf.RDMCell(65, 5, attachment.author.name, 0, 0, "R")
          pdf.ln
        end
      end
      pdf.output
    end

  end
end

Redmine::Export::PDF::IssuesPdfHelper.send(:include, PdfPatch)
