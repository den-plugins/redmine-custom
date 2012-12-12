module UsersHelper

  def users_status_options_for_select_with_archived(selected)
    user_count_by_status = User.count(:group => 'status').to_hash
    options_for_select([[l(:label_all), ''],
                        ["#{l(:status_active)} (#{user_count_by_status[1].to_i})", 1],
                        ["#{l(:status_registered)} (#{user_count_by_status[2].to_i})", 2],
                        ["#{l(:status_archived)} (#{user_count_by_status[4].to_i})", 4],
                        ["#{l(:status_locked)} (#{user_count_by_status[3].to_i})", 3]], selected)
  end

  def change_activation_link(user)
    url = {:action => 'edit', :id => user, :page => params[:page], :status => params[:status]}
    if user.locked?
      link_to l(:button_unlock), url.merge(:user => {:status => User::STATUS_ACTIVE}), :method => :post, :class => 'icon icon-unlock small'
    elsif user.archived?
      link_to l(:button_unarchive), url.merge(:user => {:status => User::STATUS_ACTIVE}), :method => :post, :class => 'icon icon-unlock small'
    elsif user.registered?
      link_to l(:button_activate), url.merge(:user => {:status => User::STATUS_ACTIVE}), :method => :post, :class => 'icon icon-unlock small'
    elsif user != User.current
      #link_to(l(:button_lock), url.merge(:user => {:status => User::STATUS_LOCKED}), :method => :post, :class => 'icon icon-lock small') +
      #content_tag("span", "&nbsp;/ ", :style => "font-size: 15px;") +
      link_to(l(:button_archive), url.merge(:user => {:status => User::STATUS_ARCHIVED}), :method => :post, :class => 'icon icon-lock small')
    end
  end
end
