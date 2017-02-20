class TimeEntryProcessor
  VALUABLE_PERSISTED_ATTRIBUTES  = %w(hours comments activity_id custom_field_values)
  VALUABLE_NEW_RECORD_ATTRIBUTES = %w(hours comments)
  
  include ActiveModel::Validations

  attr_reader :current_user, :selected_user, :time_entries, :review_day, :time_entries_attributes, :issues
  validates :current_user, presence: true
  validates :selected_user,  presence: true
  validates :time_entries_attributes, presence: true
  validate :user_can_edit_time_entries

  def initialize(args)
    @current_user = args[:current_user]
    @selected_user  = args[:selected_user]
    @review_day = args[:review_day]
    @project = args[:project]
    @time_entries_attributes = args[:params].fetch(:time_entries, {}).fetch(:time_entry, {})
    @time_entries = []
  end

  def perform
    return unless valid?
    update_issues
    update_time_entries
    validate_time_entries
  end

  def errors_messages
    @errors_messages ||= (self.errors[:base] + self.errors[:time_entries]).flatten.join('<br/>')
  end

  private

  def existing_time_entries
    @existing_time_entries ||= TimeEntry.where(id: time_entries_attributes.values.map { |attributes| attributes['id'] }).group_by(&:id)
  end

  def update_issues
    issues_attributes = time_entries_attributes.values.map { |attributes| [attributes['issue_id'].to_i, attributes['issue']] }.to_h
    select_issues(issues_attributes.keys)
    issues_attributes.each do |issue_id, attributes|
      update_issue_status(issues[issue_id], attributes)
    end
  end

  def select_issues(issue_ids)
    @issues = Issue.where(id: issue_ids).map{ |issue| [issue.id, issue] }.to_h
  end

  def update_time_entries
    time_entries_attributes.values.each do |time_entry_params|
      time_entry = select_time_entry(issues[time_entry_params['issue_id'].to_i], time_entry_params)
      new_time_entry_attributes = time_entry_params.slice!('issue', 'id', 'issue_id')

      if new_time_entry_attributes['hours'].blank? && time_entry.persisted?
        time_entry.destroy
      else
        update_time_entry(time_entry, new_time_entry_attributes)
      end
    end
  end

  def select_time_entry(issue, time_entry_params)
    existing_time_entry = time_entry_params['id'].present? && existing_time_entries[time_entry_params['id'].to_i].try(:first)
    if existing_time_entry.present?
      existing_time_entry
    else
      TimeEntry.new(project_id: issue.project_id, issue: issue, user: selected_user, spent_on: review_day)
    end
  end

  def update_issue_status(issue, issue_params)
    if issue.status_id != issue_params['status_id'].to_i
      issue.update issue_params
    end
  end

  def update_time_entry(time_entry, attributes)
    return unless has_valuable_attributes?(time_entry, attributes)
    time_entry.assign_attributes(attributes)
    if time_entry.changed_attributes.any? || time_entry.custom_field_values.any? { |field_value| field_value.value != field_value.value_was }
      time_entry.save
      @time_entries << time_entry
    end
  end

  def has_valuable_attributes?(time_entry, attributes)
    if time_entry.persisted?
      VALUABLE_PERSISTED_ATTRIBUTES.any?{ |attribute_name| attributes[attribute_name].presence }
    else
      VALUABLE_NEW_RECORD_ATTRIBUTES.any?{ |attribute_name| attributes[attribute_name].presence }
    end
  end
  
  def user_can_edit_time_entries
    if current_user && selected_user && current_user.id != selected_user.id && @project && !current_user.allowed_to?(:edit_work_time_other_member, @project)
      self.errors.add(:base, I18n.t('time_entry_processor.errors.user_can_not_edit_time_entries'))
    end
  end

  def validate_time_entries
    invalid_time_entries = @time_entries.select { |time_entry| time_entry.errors.any? }
    if invalid_time_entries.any?
      self.errors.add(:base, I18n.t('time_entry_processor.errors.some_time_entries_invalid'))
      self.errors.add(:time_entries, error_messages_for(invalid_time_entries))
    end
  end

  def error_messages_for(invalid_time_entries)
    invalid_time_entries.map do |time_entry|
      [
        I18n.t('time_entry_processor.errors.error_on_issue', issue_id: time_entry.issue_id),
        *time_entry.errors.full_messages
      ]
    end
  end
end
