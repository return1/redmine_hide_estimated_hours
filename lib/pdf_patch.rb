require_dependency 'redmine/export/pdf'

module PDFPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      alias_method_chain :issue_to_pdf, :patch
    end
  end

  module InstanceMethods

    def issue_to_pdf_with_patch(issue, assoc={})
      pdf = Redmine::Export::PDF::ITCPDF.new(current_language)
      pdf.SetTitle("#{issue.project} - #{issue.tracker} ##{issue.id}")
      pdf.alias_nb_pages
      pdf.footer_date = format_date(Date.today)
      pdf.AddPage
      pdf.SetFontStyle('B',11)
      buf = "#{issue.project} - #{issue.tracker} ##{issue.id}"
      pdf.RDMMultiCell(190, 5, buf)
      pdf.SetFontStyle('',8)
      base_x = pdf.GetX
      i = 1
      issue.ancestors.visible.each do |ancestor|
        pdf.SetX(base_x + i)
        buf = "#{ancestor.tracker} # #{ancestor.id} (#{ancestor.status.to_s}): #{ancestor.subject}"
        pdf.RDMMultiCell(190 - i, 5, buf)
        i += 1 if i < 35
      end
      pdf.SetFontStyle('B',11)
      pdf.RDMMultiCell(190 - i, 5, issue.subject.to_s)
      pdf.SetFontStyle('',8)
      pdf.RDMMultiCell(190, 5, "#{format_time(issue.created_on)} - #{issue.author}")
      pdf.Ln

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

      rows = left.size > right.size ? left.size : right.size
      while left.size < rows
        left << nil
      end
      while right.size < rows
        right << nil
      end

      half = (issue.custom_field_values.size / 2.0).ceil
      issue.custom_field_values.each_with_index do |custom_value, i|
        (i < half ? left : right) << [custom_value.custom_field.name, show_value(custom_value)]
      end

      rows = left.size > right.size ? left.size : right.size
      rows.times do |i|
        item = left[i]
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, item ? "#{item.first}:" : "", i == 0 ? "LT" : "L")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, item ? item.last.to_s : "", i == 0 ? "RT" : "R")

        item = right[i]
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35,5, item ? "#{item.first}:" : "", i == 0 ? "LT" : "L")
        pdf.SetFontStyle('',9)
        pdf.RDMCell(60,5, item ? item.last.to_s : "", i == 0 ? "RT" : "R")
        pdf.Ln
      end

      pdf.SetFontStyle('B',9)
      pdf.RDMCell(35+155, 5, l(:field_description), "LRT", 1)
      pdf.SetFontStyle('',9)

      # Set resize image scale
      pdf.SetImageScale(1.6)
      pdf.RDMwriteHTMLCell(35+155, 5, 0, 0,
                           issue.description.to_s, issue.attachments, "LRB")

      unless issue.leaf?
        # for CJK
        truncate_length = ( l(:general_pdf_encoding).upcase == "UTF-8" ? 90 : 65 )

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35+155,5, l(:label_subtask_plural) + ":", "LTR")
        pdf.Ln
        issue_list(issue.descendants.visible.sort_by(&:lft)) do |child, level|
          buf = truncate("#{child.tracker} # #{child.id}: #{child.subject}",
                         :length => truncate_length)
          level = 10 if level >= 10
          pdf.SetFontStyle('',8)
          pdf.RDMCell(35+135,5, (level >=1 ? "  " * level : "") + buf, "L")
          pdf.SetFontStyle('B',8)
          pdf.RDMCell(20,5, child.status.to_s, "R")
          pdf.Ln
        end
      end

      relations = issue.relations.select { |r| r.other_issue(issue).visible? }
      unless relations.empty?
        # for CJK
        truncate_length = ( l(:general_pdf_encoding).upcase == "UTF-8" ? 80 : 60 )

        pdf.SetFontStyle('B',9)
        pdf.RDMCell(35+155,5, l(:label_related_issues) + ":", "LTR")
        pdf.Ln
        relations.each do |relation|
          buf = ""
          buf += "#{l(relation.label_for(issue))} "
          if relation.delay && relation.delay != 0
            buf += "(#{l('datetime.distance_in_words.x_days', :count => relation.delay)}) "
          end
          if Setting.cross_project_issue_relations?
            buf += "#{relation.other_issue(issue).project} - "
          end
          buf += "#{relation.other_issue(issue).tracker}" +
              " # #{relation.other_issue(issue).id}: #{relation.other_issue(issue).subject}"
          buf = truncate(buf, :length => truncate_length)
          pdf.SetFontStyle('', 8)
          pdf.RDMCell(35+155-60, 5, buf, "L")
          pdf.SetFontStyle('B',8)
          pdf.RDMCell(20,5, relation.other_issue(issue).status.to_s, "")
          pdf.RDMCell(20,5, format_date(relation.other_issue(issue).start_date), "")
          pdf.RDMCell(20,5, format_date(relation.other_issue(issue).due_date), "R")
          pdf.Ln
        end
      end
      pdf.RDMCell(190,5, "", "T")
      pdf.Ln

      if issue.changesets.any? &&
          User.current.allowed_to?(:view_changesets, issue.project)
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(190,5, l(:label_associated_revisions), "B")
        pdf.Ln
        for changeset in issue.changesets
          pdf.SetFontStyle('B',8)
          csstr  = "#{l(:label_revision)} #{changeset.format_identifier} - "
          csstr += format_time(changeset.committed_on) + " - " + changeset.author.to_s
          pdf.RDMCell(190, 5, csstr)
          pdf.Ln
          unless changeset.comments.blank?
            pdf.SetFontStyle('',8)
            pdf.RDMwriteHTMLCell(190,5,0,0,
                                 changeset.comments.to_s, issue.attachments, "")
          end
          pdf.Ln
        end
      end

      if assoc[:journals].present?
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(190,5, l(:label_history), "B")
        pdf.Ln
        assoc[:journals].each do |journal|
          pdf.SetFontStyle('B',8)
          title = "##{journal.indice} - #{format_time(journal.created_on)} - #{journal.user}"
          title << " (#{l(:field_private_notes)})" if journal.private_notes?
          pdf.RDMCell(190,5, title)
          pdf.Ln
          pdf.SetFontStyle('I',8)
          details_to_strings(journal.details, true).each do |string|
            pdf.RDMMultiCell(190,5, "- " + string)
          end
          if journal.notes?
            pdf.Ln unless journal.details.empty?
            pdf.SetFontStyle('',8)
            pdf.RDMwriteHTMLCell(190,5,0,0,
                                 journal.notes.to_s, issue.attachments, "")
          end
          pdf.Ln
        end
      end

      if issue.attachments.any?
        pdf.SetFontStyle('B',9)
        pdf.RDMCell(190,5, l(:label_attachment_plural), "B")
        pdf.Ln
        for attachment in issue.attachments
          pdf.SetFontStyle('',8)
          pdf.RDMCell(80,5, attachment.filename)
          pdf.RDMCell(20,5, number_to_human_size(attachment.filesize),0,0,"R")
          pdf.RDMCell(25,5, format_date(attachment.created_on),0,0,"R")
          pdf.RDMCell(65,5, attachment.author.name,0,0,"R")
          pdf.Ln
        end
      end
      pdf.Output
    end

  end
end

Redmine::Export::PDF.send(:include, PDFPatch)
