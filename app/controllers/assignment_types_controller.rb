class AssignmentTypesController < ApplicationController

  before_filter :ensure_staff?

  #Display list of assignment types
  def index
    @title = "#{term_for :assignment_types}"
  end

  #See assignment type with all of its included assignments
  def show
    @assignment_type = current_course.assignment_types.find(params[:id])
    @title = "#{@assignment_type.name}"
    @score_levels = @assignment_type.score_levels
  end

  #Create a new assignment type
  def new
    @title = "Create a New #{term_for :assignment_type}"
    @assignment_type = current_course.assignment_types.new
    @assignment_type.score_levels.build
  end

  #Edit assignment type
  def edit
    @assignment_type = current_course.assignment_types.find(params[:id])
    @title = "Editing #{@assignment_type.name}"
  end

  #Create a new assignment type
  def create
    @assignment_type = current_course.assignment_types.new(params[:assignment_type])
    @assignment_type.save

    if (@assignment_type.universal_point_value?) && (@assignment_type.universal_point_value < 1)
      flash[:error] = 'Point value must be a positive number'
      render :action => "new", :assignment_type => @assignment_type
    elsif (@assignment_type.max_value?) && (@assignment_type.max_value < 1)
     flash[:error] = 'Maximum points must be a positive number'
     render :action => "new", :assignment_type => @assignment_type
    else
      respond_to do |format|
        if @assignment_type.save
          format.html { redirect_to @assignment_type, notice: "#{term_for :assignment_type} #{@assignment_type.name} successfully created" }
          format.json { render json: @assignment_type, status: :created, location: @assignment_type }
        else
          format.html { render action: "new" }
          format.json { render json: @assignment_type.errors }
        end
      end
    end
  end

  #Update assignment type
  def update
    @assignment_type = current_course.assignment_types.find(params[:id])
    @title = "Editing #{@assignment_type.name}"
    @assignment_type.update_attributes(params[:assignment_type])

    respond_to do |format|
      if (@assignment_type.universal_point_value.present?) && (@assignment_type.universal_point_value < 1)
        flash[:error] = 'Point value must be a positive number'
        format.html { render action: "new" }
        format.json { render json: @assignment_type.errors }
      elsif (@assignment_type.max_value?) && (@assignment_type.max_value < 1)
        flash[:error] = 'Maximum points must be a positive number'
        format.html { render action: "new" }
        format.json { render json: @assignment_type.errors }
      else
        if @assignment_type.save
          format.html { redirect_to assignments_path, notice: "#{term_for :assignment_type} #{@assignment_type.name} successfully updated" }
        else
          format.html { render action: "new" }
          format.json { render json: @assignment_type.errors }
        end
      end
    end
  end

  #display all grades for all assignments in an assignment type
  def all_grades  
    @assignment_type = current_course.assignment_types.find(params[:id])
    user_search_options = {}
    user_search_options['team_memberships.team_id'] = params[:team_id] if params[:team_id].present?
    @team = current_course.teams.find_by(id: params[:team_id]) if params[:team_id]
  end

  #delete the specified assignment type
  def destroy
    @assignment_type = current_course.assignment_types.find(params[:id])
    @name = "#{@assignment_type.name}"
    @assignment_type.destroy
    redirect_to assignment_types_path, :notice => "#{term_for :assignment_type} #{@name} successfully deleted"
  end
end
