class RedmineWorkTimeRedesign::Services::TableDataSelector
  attr_reader :month_dates,
              :projects,
              :project_activities,
              :issues,
              :time_entries,
              :month_visible_time_entries,
              :month_hidden_time_entries,
              :today_visible_time_entries,
              :today_hidden_time_entries,
              :issue_costs,
              :remote_work_custom_field,
              :manually_attached_data

  attr_writer :submitted_time_entries

  def initialize(args)
    @current_user = args[:current_user]
    @selected_user = args[:selected_user]
    @project = args[:project]
    @review_day = args[:review_day]
    @submitted_time_entries = args[:submitted_time_entries]
    select_necessary_data
  end

  private

  def select_necessary_data
    select_month_dates
    select_projects
    select_project_activities
    select_time_entries
    select_issues
    select_month_visible_time_entries
    select_month_hidden_time_entries
    select_today_visible_time_entries
    select_today_hidden_time_entries
    select_issue_costs
    select_remote_work_custom_field
    select_manually_attached_data
  end

  def select_month_dates
    @beginning_of_month = @review_day.beginning_of_month
    @end_of_month = @review_day.end_of_month
    @month_dates = (@beginning_of_month..@end_of_month)
  end

  def select_projects
    @projects = Project.where(id: @project.presence.try(:id) || @selected_user.projects).select { |project| project.visible?(@current_user) }
  end

  def select_project_activities
    @project_activities = projects.map { |project| [project.id, project.activities.pluck(:name, :id)] }.to_h
  end

  def select_issues
    @issues = begin
      search_attributes = { user_id: @selected_user.id, review_day: @review_day }

      collection = (
        journalized_issues(search_attributes) +
        tracked_issues(search_attributes) +
        assigned_or_authored_issues(search_attributes) +
        manually_attached_issues(search_attributes) +
        issues_assigned_to_group(search_attributes)
      )

      visible_issue_ids = Issue.where(id: collection.map(&:id) + @time_entries.pluck(:issue_id)).preload(project: :enabled_modules).select { |issue| issue.visible?(@current_user) }.map(&:id)
      collection = Issue.where(id: visible_issue_ids)
      collection = collection.where(project_id: projects.map(&:id))
      collection
    end
  end

  def journalized_issues(search_attributes)
    Issue.joins(:journals).where('journals.user_id = :user_id AND journals.created_on::date = :review_day', **search_attributes)
  end

  def tracked_issues(search_attributes)
    Issue.joins(:time_entries).where('time_entries.user_id = :user_id AND time_entries.spent_on = :review_day', **search_attributes)
  end

  def assigned_or_authored_issues(search_attributes)
    Issue.open
        .where("(issues.author_id = :user_id AND issues.created_on::date = :review_day) OR
              (issues.assigned_to_id = :user_id AND issues.start_date < :review_day)", **search_attributes)
  end

  def manually_attached_issues(search_attributes)
    Issue.select('issues.*').joins("INNER JOIN user_issue_months ON user_issue_months.issue = issues.id").where("user_issue_months.uid = :user_id", **search_attributes)
  end

  def issues_assigned_to_group(search_attributes)
    Issue.joins("LEFT JOIN groups_users on issues.assigned_to_id = group_id")
        .where("(groups_users.user_id = :user_id AND issues.start_date < :review_day)", search_attributes)
  end

  def select_time_entries
    @time_entries = begin
      time_entries = TimeEntry.preload({ issue: [:project, :status, :tracker] }, :project)
                         .where(user_id: @selected_user.id)
                         .where('"time_entries"."spent_on" >= :start_date AND "time_entries"."spent_on" <= :end_date', start_date: @beginning_of_month, end_date: @end_of_month)
      time_entries
    end
  end

  def select_month_visible_time_entries
    @month_visible_time_entries = begin
      time_entries_collection = @time_entries.joins(:issue).where.not(issue_id: nil)
      time_entries_collection = time_entries_collection.joins(:issue).where('time_entries.issue_id IN (:issue_ids) AND time_entries.project_id IN (:project_ids)', issue_ids: issues.pluck(:id), project_ids: projects.map(&:id))
      time_entries_collection
    end
  end

  def select_month_hidden_time_entries
    @month_hidden_time_entries = @time_entries.where.not(id: @month_visible_time_entries.map(&:id))
  end

  def select_today_visible_time_entries
    @today_visible_time_entries = begin
      time_entries = @month_visible_time_entries.where(spent_on: @review_day).preload(:custom_values)
      time_entries = time_entries.where.not(id: @submitted_time_entries.map(&:id).uniq.compact) if @submitted_time_entries.present?
      time_entries
    end
  end
  
  def select_today_hidden_time_entries
    @today_hidden_time_entries = @month_hidden_time_entries.where(spent_on: @review_day)
  end

  def select_issue_costs
    @issue_costs = begin
      @month_visible_time_entries.select('time_entries.project_id, time_entries.issue_id, SUM(time_entries.hours) as issue_cost')
          .group(:project_id, :issue_id)
          .map{ |time_entry| [time_entry.issue_id, time_entry.issue_cost.round(1)] }
          .to_h
    end
  end

  def select_remote_work_custom_field
    @remote_work_custom_field = TimeEntryCustomField.find_by_name('Удаленная работа')
  end

  def select_manually_attached_data
    @manually_attached_data = UserIssueMonth.where(uid: @selected_user.id).pluck(:issue, :id).to_h
  end
end
