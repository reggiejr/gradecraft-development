class User < ActiveRecord::Base
  authenticates_with_sorcery!

  include Canable::Cans

  before_validation :set_default_course
  after_save :cache_scores

  ROLES = %w(student professor gsi admin)

  ROLES.each do |role|
    scope role.pluralize, -> { where role: role }
  end

  attr_accessor :remember_me, :password, :password_confirmation, :cached_last_login_at, :course_team_ids
  attr_accessible :username, :email, :password, :password_confirmation,
    :avatar_file_name, :role, :first_name, :last_name, :rank, :user_id,
    :display_name, :private_display, :default_course_id, :last_activity_at,
    :last_login_at, :last_logout_at, :team_ids, :courses, :course_ids,
    :shared_badges, :earned_badges, :earned_badges_attributes,
    :remember_me_token, :major, :gpa, :current_term_credits, :accumulated_credits,
    :year_in_school, :state_of_residence, :high_school, :athlete, :act_score, :sat_score,
    :student_academic_history_attributes, :team_role, :course_memberships_attributes,
    :character_profile, :team_id, :lti_uid, :course_team_ids

  scope :alpha, -> { order 'last_name ASC' }
  scope :order_by_high_score, -> { order 'course_memberships.score DESC' }
  scope :order_by_low_score, -> { order 'course_memberships.score ASC' }
  scope :being_graded, -> { where('course_memberships.auditing IS FALSE') }
  scope :auditing, -> { where('course_memberships.auditing IS TRUE') }

  has_many :course_memberships, :dependent => :destroy
  has_one :student_academic_history, :foreign_key => :student_id, :dependent => :destroy, :class_name => 'StudentAcademicHistory'
  accepts_nested_attributes_for :student_academic_history
  has_many :courses, :through => :course_memberships
  has_many :course_users, :through => :courses, :source => 'users'
  accepts_nested_attributes_for :courses
  accepts_nested_attributes_for :course_memberships
  belongs_to :default_course, :class_name => 'Course'

  has_many :assignment_weights, :foreign_key => :student_id
  has_many :assignments, :through => :grades

  has_many :submissions, :foreign_key => :student_id, :dependent => :destroy
  has_many :created_submissions, :as => :creator
  has_many :grades, :foreign_key => :student_id, :dependent => :destroy
  has_many :graded_grades, foreign_key: :graded_by_id, :class_name => 'Grade'

  has_many :earned_badges, :foreign_key => :student_id, :dependent => :destroy
  accepts_nested_attributes_for :earned_badges, :reject_if => proc { |attributes| attributes['earned'] != '1' }

  has_many :badges, :through => :earned_badges

  has_many :group_memberships, :foreign_key => :student_id, :dependent => :destroy
  has_many :groups, :through => :group_memberships
  has_many :assignment_groups, :through => :groups

  has_many :team_memberships, :foreign_key => :student_id, :dependent => :destroy

  has_many :teams, :through => :team_memberships do
    def set_for_course(course_id, ids)
      other_team_ids = proxy_association.owner.teams.where("course_id != ?", course_id).pluck(:id)
      if  proxy_association.owner.role == "student"
        proxy_association.owner.team_ids = other_team_ids | [ids]
      else
        if ids.present?
          proxy_association.owner.team_ids = other_team_ids | ids
        end
      end
    end
  end

  email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  validates :username, :presence => true,
                    :length => { :maximum => 50 }
  validates :email, :presence => true,
                    :format   => { :with => email_regex },
                    :uniqueness => { :case_sensitive => false }

  validates :first_name, :last_name, :presence => true

  def self.find_or_create_by_lti_auth_hash(auth_hash)
    criteria = { email: auth_hash['info']['email'] }
    where(criteria).first || create!(criteria) do |u|
      u.lti_uid = auth_hash['uid']
      auth_hash['info'].tap do |info|
        u.first_name = info['first_name']
        u.last_name = info['last_name']
      end
      auth_hash['extra']['raw_info'].tap do |extra|
        if extra['tool_consumer_info_product_family_code'] == "sakai"
          u.username = extra['ext_sakai_eid']
          u.kerberos_uid = extra['ext_sakai_eid']

        elsif extra['tool_consumer_info_product_family_code'] == "canvas"
          u.username = extra['custom_canvas_user_login_id']
          u.kerberos_uid = extra['custom_canvas_user_login_id']
        end

        case extra['roles']
        when 'instructor'
          u.role = 'professor'
        else
          u.role = 'student'
        end
      end
    end
  end

  def self.find_by_kerberos_auth_hash(auth_hash)
    where(kerberos_uid: auth_hash['uid']).first
  end

  #Course
  def find_scoped_courses(course_id)
    if is_admin? || self.course_ids.include?(course_id)
      Course.find(course_id)
    else
      raise
    end
  end

  def default_course
    courses.where(id: default_course_id) || courses.first
  end

  def name
    @name = [first_name,last_name].reject(&:blank?).join(' ').presence || "User #{id}"
  end

  def public_name
    if display_name?
      display_name
    else
      name
    end
  end

  def multiple_courses?
    course_memberships.count > 1
  end

  def team_leader
    teams.first.try(:team_leader)
  end

 def is_prof?
    role == "professor"
  end

  def is_gsi?
    role == "gsi"
  end

  def is_student?
    role == "student" || role.blank?
  end

  def is_admin?
    role == "admin"
  end

  def role
    super || "student"
  end

  def is_staff?
    is_prof? || is_gsi? || is_admin?
  end

  # Find the team associated with the team membership for a given course id
  def course_team(course)
    team_memberships.where("teams.course_id = ?", course.id) rescue nil
  end

  def character_profile(course)
    course_memberships.where(course: course).try('character_profile')
  end

  #Submissions - can be taken out?

  def submissions_by_assignment_id
    @submissions_by_assignment ||= submissions.group_by(&:assignment_id)
  end

  def submission_for_assignment(assignment)
    submissions_by_assignment_id[assignment.id].try(:first)
  end

  #Badges - can be taken out?

  def earned_badges_by_badge_id
    @earned_badges_by_badge ||= earned_badges.group_by(&:badge_id)
  end

  def earned_badge_score_for_course(course)
    earned_badges.where(:course_id => course).score
  end

  def earned_badges_for_course(course)
    @earned_badges ||= {}.tap do |earned_badges|
      self.earned_badges.where(course: course).each do |earned_badge|
        earned_badges[earned_badge.badge_id] = earned_badge
      end
    end
  end

  def earned_badge_count_for_course(course)
    earned_badges.where(course: course).count
  end

  def earned_badge_score
    @earned_badge_score ||= earned_badges.sum(:score)
  end

  #grabbing the stored score for the current course
  def cached_score_for_course(course)
    course_memberships.where(:course_id => course).first.score || 0
  end

  #I think this may be a little bit faster - ch
  def scores_for_course(course)
     user_score = course_memberships.where(:course_id => course, :auditing => FALSE).pluck('score')
     scores = course.students.being_graded.pluck('score')
     return {
      :scores => scores,
      :user_score => user_score
     }
  end


  #recalculating the student's score for the course
  def score_for_course(course)
    @score_for_course ||= grades.released.where(course: course).score + earned_badge_score_for_course(course) + (team_for_course(course).try(:challenge_grade_score) || 0)
  end

  def predictions(course)
    scores = []
    course.assignment_types.each do |assignment_type|
      scores << { data: [grades.released.where(assignment_type: assignment_type).score], name: assignment_type.name }
    end


    _assignments = assignments.where(course: course)
    in_progress = _assignments.graded_for_student(self)

    if course.valuable_badges? && course.has_team_challenges?
      earned_badge_score = earned_badges.where(course: course).score
      team_score = self.team_for_course(course).score
      scores << { :data => [team_score], :name => "#{course.challenge_term.pluralize}" }
      scores << { :data => [earned_badge_score], :name => "#{course.badge_term.pluralize}" }
      return {
        :student_name => name,
        :scores => scores,
        :course_total => course.total_points + earned_badge_score + team_score,
        :in_progress => in_progress.point_total + earned_badge_score + team_score
        }
    elsif course.valuable_badges?
      earned_badge_score = earned_badges.where(course: course).score
      scores << { :data => [earned_badge_score], :name => "#{course.badge_term.pluralize}" }
      return {
        :student_name => name,
        :scores => scores,
        :course_total => course.total_points + earned_badge_score,
        :in_progress => in_progress.point_total + earned_badge_score
        }
    elsif course.has_team_challenges?
      team_score = self.team_for_course(course).score
      scores << { :data => [team_score], :name => "#{course.challenge_term.pluralize}" }
      return {
        :student_name => name,
        :scores => scores,
        :in_progress => in_progress.point_total + team_score,
        :course_total => course.total_points + team_score
        }
    else
      return {
        :student_name => name,
        :scores => scores,
        :in_progress => in_progress.point_total,
        :course_total => course.total_points
        }
    end
  end

  #student setting as to whether or not they wish to share their earned badges for this course
  def badges_shared(course)
    course_memberships.any? { |m| m.course_id = course.id and m.shared_badges }
  end

  def grade_level_for_course(course)
    course.grade_level_for_score(cached_score_for_course(course))
  end

  def grade_letter_for_course(course)
    @grade_letter_for_course ||= course.grade_letter_for_score(cached_score_for_course(course))
  end

  def next_element_level(course)
    n = 1
    stop = 0
    level = ''
    course.grade_scheme_elements.order_by_low_range.each do |element|
      n += 1
      if n == stop
        level = element.level
      end
      if element.high_range >= cached_score_for_course(course) && cached_score_for_course(course) >= element.low_range
        stop = n + 1
      end
    end
    if level == ''
      return false
    else
      return level
    end
  end

  def point_total_for_course(course)
    @point_total_for_course ||= course.assignments.point_total_for_student(self) + earned_badge_score_for_course(course)
  end

  def point_total_for_assignment_type(assignment_type)
    assignment_type.assignments.point_total_for_student(self)
  end

  def scores_by_assignment_type
    grades.group(:assignment_type_id).pluck('assignment_type_id, SUM(score)')
  end

  def score_for_assignment_type(assignment_type)
    grades.where(assignment_type: assignment_type).score
  end

  def grade_for_assignment(assignment)
    grades.where(assignment: assignment).first
  end

  def released_score_for_assignment_type(assignment_type)
    grades.released.where(assignment_type: assignment_type).score
  end

  def weights_for_assignment_type_id(assignment_type)
    assignment_weights.where(assignment_type: assignment_type).weight
  end

  def weighted_assignments?
    @weighted_assignments_present ||= assignment_weights.count > 0
  end

  #Used for self-logged attendance to check if the student already has a grade
  def present_for_class?(assignment)
    grade_for_assignment(assignment).try(:score) == assignment.point_total
  end

  #Counts how many assignments are weighted for this student - note that this is an ASSIGNMENT count, and not the assignment type count. Because students make the choice at the AT level rather than the A level, this can be confusing.
  def weight_count(course)
    assignment_weights.where(course: course).pluck('weight').count
  end

  def groups_by_assignment_id
    @group_by_assignment ||= groups.group_by(&:assignment_id)
  end

  def group_for_assignment(assignment)
    assignment_groups.where(assignment: assignment).first.try(:group)
  end

  def team_for_course(course)
    teams.where(course_id: course).first
  end

  #Auditing Course

  def auditing_course?(course)
    course.membership_for_student(self).auditing?
  end

  #Import Users
  def self.csv_header
    "First Name,Last Name,Email,Username".split(',')
  end

  #Export Users and Final Scores for Course
  def self.csv_for_course(course, options = {})
    CSV.generate(options) do |csv|
      csv << ["GradeCraft ID", "First Name", "Last Name", "Email", "Score", "Grade" ]
      course.students.each do |student|
        csv << [student.id, student.first_name, student.last_name, student.email, student.score_for_course(course)]
      end
    end
  end

  def self.csv_roster_for_course(course, options = {})
    CSV.generate(options) do |csv|
      csv << ["GradeCraft ID, First Name", "Last Name", "Uniqname", "Score", "Grade", "Feedback", "Team"]
      course.students.each do |student|
        csv << [student.id, student.first_name, student.last_name, student.username, "", "", "", student.team_for_course(course).try(:name) ]
      end
    end
  end

  def team_score(course)
    teams.where(:course => course).pluck('score').first
  end

  def default_course
    super || courses.first
  end

  def predictions(course)
    scores = []
    course.assignment_types.each do |assignment_type|
      scores << { data: [grades.released.where(assignment_type: assignment_type).score], name: assignment_type.name }
    end


    _assignments = assignments.where(course: course)
    in_progress = _assignments.graded_for_student(self)

    if course.valuable_badges?
      earned_badge_score = earned_badges.where(course: course).score
      scores << { :data => [earned_badge_score], :name => "#{course.badge_term.pluralize}" }
      return {
        :student_name => name,
        :scores => scores,
        :course_total => course.total_points + earned_badge_score,
        :in_progress => in_progress.point_total + earned_badge_score
        }
    else
      return {
        :student_name => name,
        :scores => scores,
        :in_progress => in_progress.point_total,
        :course_total => course.total_points
        }
    end
  end

  def archived_courses
    courses.where(:status => false)
  end

  private

  def set_default_course
    self.default_course ||= courses.first
  end

  def cache_scores
    course_memberships.each do |membership|
      if membership.course.add_team_score_to_student?
        membership.update_attribute :score, grades.released.where(course_id: membership.course_id).score + earned_badge_score_for_course(membership.course_id) + (team_for_course(membership.course_id).try(:challenge_grade_score) || 0)
      else
        membership.update_attribute :score, grades.released.where(course_id: membership.course_id).score + earned_badge_score_for_course(membership.course_id)
      end
    end
  end

  def cache_last_login
    self.cached_last_login_at = self.last_login_at
  end
end
