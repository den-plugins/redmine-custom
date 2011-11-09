class MyController < ApplicationController
  
  before_filter :filter, :only => [:page, :page_layout, :add_block]
  
  private
  def filter
    @milestone_filter = 1
    @output = case params[:milestone]
                            when "1"; [1,2]
                            else; [2]
                            end
  end
end
