class HolidaysController < ApplicationController
  before_filter :require_login, :except => [:save_holidays, :update_holidays]
  before_filter :get_holiday, :only => [:update, :destroy]
  skip_before_filter :check_if_login_required, :only => [:save_holidays, :update_holidays]
  before_filter :restrict_access, :only => [:save_holidays, :update_holidays]

  helper :sort
  include SortHelper

  def index
    sort_init 'event_date'
    sort_update	'event_date'
    @holiday = Holiday.all :order => sort_clause
    render :action => 'index', :layout => !request.xhr?
  end

  def add
    if request.get?
      @holiday = Holiday.new
      render :template => "holidays/add" 
    else
      @holiday = Holiday.create(params[:holiday])
      if @holiday.errors.empty?
        flash[:notice] = l(:notice_successful_create)
        redirect_to_holidays
      else
        render :template => "holidays/add"
      end
    end
  end
  
  def update
    if request.get?
      render :template => "holidays/edit"
    else
      if @holiday.update_attributes(params[:holiday])
        flash[:notice] = l(:notice_successful_update)
        redirect_to_holidays
      else
        render :template => "holidays/edit"
      end
    end
  end

  def destroy
    if @holiday.destroy
      redirect_to_holidays
    end
  end

  def save_holidays
    if params[:date] && params[:title] && params[:description] && params[:location]
      holiday = Holiday.new
      holiday.event_date = Date.parse(params[:date])
      holiday.title = params[:title]
      holiday.description = params[:description]
      holiday.location = params[:location]
      if holiday.save
        render :json => { :save_complete => true, :holiday_id => holiday.id }.to_json
      else
        render :json => { :save_complete => false, :holiday_id => nil }.to_json
      end
    else
      render :json => { :save_complete => false, :holiday_id => nil }.to_json
    end
  end

  def update_holidays
    if params[:holiday_id] || params[:date] || params[:title] || params[:description] || params[:location]
      holiday = Holiday.find(params[:holiday_id])
      holiday.event_date = Date.parse(params[:date]) if params[:date]
      holiday.title = params[:title] if params[:title]
      holiday.description = params[:description] if params[:description]
      holiday.location = params[:location] if params[:location]
      if holiday.save
        render :json => { :save_complete => true }.to_json
      else
        render :json => { :save_complete => false }.to_json
      end
    else
      render :json => { :save_complete => false }.to_json
    end
  end

  private
  
  def get_holiday
    @holiday = Holiday.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
  end

  def redirect_to_holidays
    redirect_to :controller => 'holidays'
  end

  def restrict_access
    head :unauthorized unless params[:access_token].eql? AUTH_TOKEN
  end
end
