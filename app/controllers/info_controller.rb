class InfoController < ApplicationController

  respond_to :html

  helper_method :sort_column, :sort_direction
  
  before_filter :require_login, :except => [:people, :research, :submit_a_bug, :news, :features, :using_gradecraft]


  def dashboard
    if current_user.is_staff?
      @teams = current_course.teams.includes(:challenge_grades, :earned_badges)
      @users = current_course.users.includes(:groups, :earned_badges)
      @students = @users.students
      @top_ten_students = @students.order('course_memberships.sortable_score DESC').limit(10)
      @bottom_ten_students = @students.order('course_memberships.sortable_score ASC').limit(10)
    end
    @badges = current_course.badges.includes(:earned_badges, :elements)
    @user = current_user
    @assignments = current_course.assignments.includes(:assignment_submissions, :assignment_type)
    @assignment_types = current_course.assignment_types.includes(:assignments)
    @submissions = current_course.assignment_submissions
  end
end
