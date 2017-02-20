class RedmineWorkTimeRedesign::Services::TableDataPresenter
  attr_reader :selected_user,
              :current_user,
              :month_dates,
              :projects,
              :review_day,
              :issues,
              :order,
              :issue_costs
              :time_entries

  def initialize(args)
    @current_user = args[:current_user]
    @selected_user = args[:selected_user]
    @review_day = args[:review_day]
    @order = args[:order] && args[:order].upcase
    @submitted_time_entries = args[:submitted_time_entries] || []
    set_necessary_attributes(args)
  end

  def month_table_label
    month = if I18n.locale == :ru
      "#{I18n.t('date.standalone_month_names')[review_day.month]} #{review_day.year}"
    else
     I18n.l(review_day, format: :month_and_year)
    end
    I18n.t(:wt_month_table_label, month: month).mb_chars.upcase
  end

  def month_table
    @month_table ||= begin
      month_table = select_month_visible_data
      month_table.merge!(select_month_hidden_data)
      month_table.merge!(count_month_total_data(month_table.keys))
      month_table
    end
  end

  def day_table
    @day_table ||= begin
      day_table = select_today_visible_data
      day_table.merge!(select_today_hidden_data)
      day_table.merge!(count_today_total_data(day_table.keys))
      day_table
    end
  end

  private

  def set_necessary_attributes(args)
    data_selector = RedmineWorkTimeRedesign::Services::TableDataSelector.new(args)
    @month_dates = data_selector.month_dates
    @projects = data_selector.projects
    @project_activities = data_selector.project_activities
    @issues = data_selector.issues
    @time_entries = data_selector.time_entries
    @month_visible_time_entries = data_selector.month_visible_time_entries
    @month_hidden_time_entries = data_selector.month_hidden_time_entries
    @today_visible_time_entries = data_selector.today_visible_time_entries
    @today_hidden_time_entries = data_selector.today_hidden_time_entries
    @issue_costs = data_selector.issue_costs
    @remote_work_custom_field = data_selector.remote_work_custom_field
    @manually_attached_data = data_selector.manually_attached_data
  end

  def select_month_visible_data
    groupped_time_entries = @month_visible_time_entries.group_by(&:project)
                                .map { |project, time_entries| [project, time_entries.group_by(&:issue).except(nil)]}
                                .sort_by { |project, _| project.id }
    groupped_time_entries.map do |project, issues_with_time_entries|
      time_entry_rows = create_time_entry_rows(issues_with_time_entries)
      section_data = initialize_month_table_section_data(project, :regular, count_total_hours_by_days(time_entry_rows.values))
      [section_data, time_entry_rows]
    end.to_h
  end

  def select_month_hidden_data
    time_entries = @month_hidden_time_entries
    section_data = initialize_month_table_section_data(nil, :hidden, count_hours_by_days(time_entries))
    section_data.total_hours > 0 ? { section_data => [] } : {}
  end

  def count_month_total_data(sections)
    { initialize_month_table_section_data(nil, :total, count_total_hours_by_days(sections.map(&:total_hours_by_days))) => [] }
  end

  def initialize_month_table_section_data(project, type, total_hours_by_days)
    name = project ? project.name : I18n.t("wt_section_#{type}", default: '')
    Struct.new(:name, :total_hours, :total_hours_by_days).new(name, total_hours_by_days.compact.sum || 0.0, total_hours_by_days)
  end

  def create_time_entry_rows(issues_with_time_entries)
    issues_with_time_entries.map do |issue, time_entries|
      [issue, count_hours_by_days(time_entries)]
    end.to_h
  end

  def count_total_hours_by_days(time_entry_rows)
    time_entry_rows.transpose.map{ |hours_by_day| hours_by_day[0].nil? ? nil : hours_by_day.sum }
  end

  def count_hours_by_days(time_entries)
    time_entries_by_days = time_entries.group_by(&:spent_on)
    month_dates.map do |date|
      if date > Date.today
        nil
      else
        time_entries = time_entries_by_days[date]
        time_entries.present? ? time_entries.map(&:hours).compact.sum : 0.0
      end
    end
  end

  def select_today_visible_data
    time_entries_for_issues = join_time_entries(@today_visible_time_entries)
    time_entries_for_issues = add_empty_time_entries(time_entries_for_issues)
    time_entries_for_issues.group_by(&:project).map do |project, time_entries|
      time_entries_data_array = time_entries_data(time_entries)
      time_entries_data_array = order_time_entries_data(time_entries_data_array)
      [initialize_day_table_section_data(project, :regular, sum_hours(time_entries.map(&:hours))), time_entries_data_array]
    end.sort_by { |project_data, _| project_data.id }.to_h
  end

  def join_time_entries(time_entries_collection)
    @submitted_time_entries.present? ? (time_entries_collection + @submitted_time_entries) : time_entries_collection
  end

  def order_time_entries_data(time_entries_data)
    if @order
      order_direction_coefficient = @order == 'DESC' ? -1 : 1
      time_entries_data.sort { |time_entry_data| time_entry_data[:time_entry].hours.to_f * order_direction_coefficient }
    else
      time_entries_data
    end
  end

  def add_empty_time_entries(time_entries_for_issues)
    issues_with_time_entries = time_entries_for_issues.map(&:issue_id)
    issues_with_no_time_entires = issues.reject { |issue| issues_with_time_entries.include?(issue.id) }
    if issues_with_no_time_entires.any?
      time_entries_for_issues + issues_with_no_time_entires.map { |issue| new_empty_time_entry_for(issue) }
    else
      time_entries_for_issues
    end
  end

  def new_empty_time_entry_for(issue)
    TimeEntry.new(project_id: issue.project.id, issue: issue, user_id: selected_user.id, spent_on: review_day)
  end

  def select_today_hidden_data
    total_hours = sum_hours(@today_hidden_time_entries.map(&:hours))
    if total_hours > 0
      { initialize_day_table_section_data(nil, :hidden, total_hours) => [] }
    else
      {}
    end
  end

  def initialize_day_table_section_data(project, type, total_hours_by_day)
    id = project ? project.id : -1
    name = project ? project.name : I18n.t("wt_section_#{type}", default: '')
    Struct.new(:id, :name, :total_hours_by_day).new(id, name, total_hours_by_day)
  end

  def count_today_total_data(sections)
    { initialize_day_table_section_data(nil, :total, sections.map(&:total_hours_by_day).sum) => [] }
  end

  def time_entries_data(time_entries)
    time_entries.group_by(&:issue).map do |issue, time_entries|
      common_data = common_time_entries_data(issue, time_entries)
      time_entries.map do |time_entry|
        common_data.merge(time_entry: time_entry, remote: remote_work_for(time_entry))
      end
    end.flatten
  end

  def remote_work_for(time_entry)
    if @remote_work_custom_field
      time_entry.custom_field_values.find { |value| value.custom_field_id == @remote_work_custom_field.id }.try(:value) == '1'
    else
      false
    end
  end

  def common_time_entries_data(issue, time_entries)
    {
      issue: issue,
      user_issue_month_id: @manually_attached_data[issue.id],
      activities: @project_activities[issue.project_id] || [],
      total_issue_hours: sum_hours(time_entries.map(&:hours)),
      allowed_issue_statuses: issue.new_statuses_allowed_to(current_user).to_a,
      issue_cost: issue_costs[issue.id],
      remote_work_custom_field_id: @remote_work_custom_field.try(:id),
      remote_work_custom_field_name: @remote_work_custom_field.try(:name)
    }
  end

  def sum_hours(hours)
    hours.map(&:to_f).sum.round(1)
  end
end
