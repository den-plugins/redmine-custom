require 'app/helpers/application_helper'

module CustomIssuesHelper
  def reauthoring(created, author, options={})
    timevar = []
    timevar << "#{created}, #{distance_of_time_in_words(Time.now, created)}"
    time_tag = @project.nil? ? content_tag('acronym', created, :title => format_time(created)) :
        link_to(timevar,
                {:controller => 'projects', :action => 'activity', :id => @project, :from => created.to_date},
                :title => format_time(created))
    author_tag = (author.is_a?(User) && !author.anonymous?) ? link_to(h(author), :controller => 'account', :action => 'show', :id => author) : h(author || 'Anonymous')
    l(options[:label] || :label_added_time_by, :author => author_tag, :age => time_tag)
  end
end
