module Custom
  module IssuesControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :new, :acctg_types
        alias_method_chain :show, :acctg_types
      end
    end

    module InstanceMethods

      def new_with_acctg_types
        @accounting_types = AccountingType.all
        respond_to do |format|
          format.html { render :action => 'new', :layout => !request.xhr? }
          format.js { render :partial => 'update_form' }
        end
      end

      def show_with_acctg_types
        @journals = @issue.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
        @journals.each_with_index {|j,i| j.indice = i+1}
        @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
        @journals.reverse! if User.current.wants_comments_in_reverse_order?

        @changesets = @issue.changesets.visible.all
        @changesets.reverse! if User.current.wants_comments_in_reverse_order?

        @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
        @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
        @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
        @priorities = IssuePriority.active

        @accounting_types = AccountingType.all

        @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
        respond_to do |format|
          format.html {
            retrieve_previous_and_next_issue_ids
            render :template => 'issues/show'
          }
          format.api
          format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
          format.pdf  {
            pdf = issue_to_pdf(@issue, :journals => @journals)
            send_data(pdf, :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf")
          }
        end
      end

    end
  end
end
