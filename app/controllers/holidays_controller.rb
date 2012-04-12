class HolidaysController < ApplicationController
  
  before_filter :require_login
  before_filter :get_holiday, :only => [:update, :destroy]

  def index
    @holiday = Holiday.all :order => 'event_date'
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
    
  private
  
  def get_holiday
    @holiday = Holiday.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
  end

  def redirect_to_holidays
    redirect_to :controller => 'holidays'
  end
end
