require_dependency 'application'
module IssuesControllerPatch

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :show, :limit_journals
    end
  end

  module InstanceMethods
    def show_with_limit_journals
      @journals = @issue.journals.find(:all, 
                                       :include => [:user, :details], 
                                       :order => "#{Journal.table_name}.created_on DESC", 
                                       :limit => (params[:show_more].blank? ? 10 : nil))
      @total_journals = @issue.journals.count
      @journals.each_with_index {|j,i| j.indice = i+1}
      @journals.reverse! if User.current.wants_comments_in_reverse_order?
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
		  if params[:show_more].blank?
        respond_to do |format|
          format.html { render :template => 'issues/show.rhtml', :locals => {:prv => prv_issue, :nxt => nxt_issue} } # for feature #8364 - added locals
          format.atom { render :action => 'changes', :layout => false, :content_type => 'application/atom+xml' }
          format.pdf  { send_data(issue_to_pdf(@issue), :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf") }
        end
      else
        render :partial => 'issues/history', :locals => { :journals => @journals }
      end
    end
  end

end
