require_dependency 'application'
module IssuesControllerPatch

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :show, :limit_journals
      alias_method_chain :edit, :mystic_tickets
    end
  end

  module InstanceMethods
  
    def edit_with_mystic_tickets
      @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
      @priorities = Enumeration.priorities
      @accounting = Enumeration.accounting_types
      @default = @issue.accounting.id
      @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
      @time_entry = TimeEntry.new
      @update_options = {'Internal (DEN only)' => 1, 'Include Mystic' => 2}

      @notes = params[:notes]
      journal = @issue.init_journal(User.current, @notes)
      # User can change issue attributes only if he has :edit permission or if a workflow transition is allowed
      if (@edit_allowed || !@allowed_statuses.empty?) && params[:issue]
        attrs = params[:issue].dup
        attrs.delete_if {|k,v| !UPDATABLE_ATTRS_ON_TRANSITION.include?(k) } unless @edit_allowed
        attrs.delete(:status_id) unless @allowed_statuses.detect {|s| s.id.to_s == attrs[:status_id].to_s}
        issue_clone = @issue.clone
        @issue.predefined_tasks = params[:issue]['predefined_tasks']
        @issue.attributes = attrs
      end

      if request.post?
        Issue.transaction do
          @time_entry = TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => Date.today)
          @time_entry.attributes = params[:time_entry]
          attachments = attach_files(@issue, params[:attachments])
          attachments.each {|a| journal.details << JournalDetail.new(:property => 'attachment', :prop_key => a.id, :value => a.filename)}

          call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => @time_entry, :journal => journal})
          unless @issue.assigned_to.nil?
            @issue.errors.add_to_base "Cannot assign to resigned resource." if employee_status == "Resigned"
          end
          if (@time_entry.hours.nil? || @time_entry.valid?) && @issue.errors.empty? && @issue.save
            # Log spend time
            if User.current.allowed_to?(:log_time, @project)
              @time_entry.save
              if !@time_entry.hours.nil?
                journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'hours', :value => @time_entry.hours)
                journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'activity_id', :value => @time_entry.activity_id)
                journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'spent_on', :value => @time_entry.spent_on)
                if !@issue.estimated_hours.nil?
                  total_time_entry = TimeEntry.sum(:hours, :conditions => "issue_id = #{@issue.id}")
                  remaining_estimate = @issue.estimated_hours - total_time_entry
                  journal.details << JournalDetail.new(:property => 'timelog', :prop_key => 'remaining_estimate',
                                                       :value => remaining_estimate >= 0 ? remaining_estimate : 0)
                end
                #journal.save
              end
              if !@time_entry.hours.nil? || !journal.notes.blank?
                journal.save
              end
            end
            if !journal.new_record? && flash[:error].nil?
              # Only send notification if something was actually changed
              flash[:notice] = l(:notice_successful_update)
            end
            call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => @time_entry, :journal => journal})
            if update_ticket_at_mystic?
              return(update_mystic_ticket(@issue, @notes))
            else
              redirect_to(params[:back_to] || {:controller => 'issues', :action => 'show', :id => @issue})
            end
          else
            render :template => "issues/edit", :layout => !request.xhr?
          end
        end # transaction end
      end
    rescue ActiveRecord::StaleObjectError
      # Optimistic locking exception
      flash[:error] = l(:notice_locking_conflict)
      redirect_to(params[:back_to] || {:controller => 'issues', :action => 'edit', :id => @issue})
    end
    
    def show_with_limit_journals
      @spent_time_disable = @project.lock_time_logging >= Date.today ? true : false rescue false
      @total_journals = @issue.journals.count("journals.id", 
                                              :include => [:user, :details], 
                                              :conditions => ["#{JournalDetail.table_name}.property <> 'timelog' OR #{Journal.table_name}.notes is not null AND #{Journal.table_name}.notes <> ''"])
      @journal_pages = IssuesController::Paginator.new self, @total_journals, 10, params['page']
      offset = @journal_pages.current.offset
      @journals = @issue.journals.find(:all, 
                                       :include => [:user, :details],
                                       :conditions => ["#{JournalDetail.table_name}.property <> 'timelog' OR #{Journal.table_name}.notes is not null AND #{Journal.table_name}.notes <> ''"],
                                       :order => "#{Journal.table_name}.created_on #{User.current.wants_comments_in_reverse_order? ? 'DESC' : 'ASC'}", 
                                       :limit => 10,
                                       :offset => offset)
      
      if User.current.wants_comments_in_reverse_order?
        @journals.each_with_index {|j,i| j.indice = (@total_journals - offset) - i}
      else
        @journals.each_with_index {|j,i| j.indice = (offset + i)+1}
      end
		  if params['page'].blank?
        @changesets = @issue.changesets
        @changesets.reverse! if User.current.wants_comments_in_reverse_order?
        @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
        @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
        @logtime_allowed = TimeEntry.logtime_allowed?(User.current, @project)
        @priorities = Enumeration.priorities
        @accounting = Enumeration.accounting_types
        @default = @issue.accounting.id
        @time_entry = TimeEntry.new
        @update_options = {'Internal (DEN only)' => 1, 'Include Mystic' => 2}

		    # for feature #8364
		    issues = @project.issues.collect {|pi| pi.id}.sort
		    index = issues.index(@issue.id)
		    if !index.nil?
			    prv_issue = (index-1 >= 0) ? issues[index-1] : 0
			    nxt_issue = (index+1 < issues.size) ? issues[index+1] : 0
		    end
		    #
        respond_to do |format|
          format.html { render :template => 'issues/show.rhtml', :locals => {:prv => prv_issue, :nxt => nxt_issue} } # for feature #8364 - added locals
          format.atom { render :action => 'changes', :layout => false, :content_type => 'application/atom+xml' }
          format.pdf  { send_data(issue_to_pdf(@issue), :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf") }
        end
      else
        render :update do |page|
          page.replace_html :history_content, :partial => 'issues/history', :locals => { :journals => @journals }
        end
      end
    end
  end

end
