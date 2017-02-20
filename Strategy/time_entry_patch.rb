# Патч для модели TimeEntry
# Создание данного модуля преследовало две цели:
# 1. Позволить некоторому списку людей редактировать затраченные на работу часы в течение недели(в отличие от основной
#    массы людей, которые могут редактировать только за последние два дня)
# 2. Собрать в одном месте всю достаточно сложную логику валидаций для TimeEntry.
module TimeEntryPatch

  if Rails.env.test?
    NEW_STATUS_ID = 1
    CLOSED_STATUSES_ID = [5]
  else
    NEW_STATUS_ID = IssueStatus.where(name: 'New').first.try(:id)
    CLOSED_STATUSES_ID = IssueStatus.where(is_closed: true).pluck(:id).freeze
  end

  def self.prepended(base)
   base.validates_presence_of :comments, :issue
   base.validates_length_of :comments, :minimum => 5, :allow_blank => false
   base.validate :issue_new
   base.validate :issue_closed

   base.validate :control_date
   base.before_destroy :can_destroy?
  end

  private

  def control_date
    # Используется паттерн "Стратегия", позволяющий включать совершенно различную логику, в зависимости от небольшого количества параметров.
    if exclusive_user?
      validate_strategy = ExclusiveTimeTrackStrategy.new(self)
    else
      validate_strategy = TimeTrackStrategy.new(self)
    end
    validate_strategy.process!
    not self.errors.any?
  end

  def can_destroy?
    not TimeTrackStrategy.new(self).sl_status_blocked?
  end

  def exclusive_user?
    track_settings = RedmineControlTimeEntry.settings
    return false unless track_settings[:exclusive_users]
    track_settings[:exclusive_users].include?(User.current.id.to_s && user_id.to_s)
  end

  def issue_new
    return true unless project and RedmineControlTimeEntry.projects_prevent_new.include? project_id
    if issue and issue.status_id == NEW_STATUS_ID
      errors.add :base, I18n.t(:unable_track_new_issue)
    end
  end

  def issue_closed
    return true unless project and RedmineControlTimeEntry.projects_prevent_closed.include? project_id
    if issue and CLOSED_STATUSES_ID.include? issue.status_id
      errors.add :base, I18n.t(:unable_track_closed_issue)
    end
  end

end

TimeEntry.send(:prepend, TimeEntryPatch)
