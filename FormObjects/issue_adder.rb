# Просто пример FormObject'а

class RedmineWorkTimeRedesign::FormObjects::IssueAdder
  include ActiveModel::Validations

  attr_reader :user, :issue_id, :issue

  validates :user, presence: true
  validate  :issue_exists
  validate  :user_does_not_have_issue

  def initialize(user, issue_id)
    @user = user
    @issue_id = issue_id
    find_issue
  end

  def perform
    valid? ? UserIssueMonth.create!(uid: user.id, issue: issue_id) : false
  end

  private

  def find_issue
    @issue ||= Issue.find_by(id: issue_id)
  end

  def user_does_not_have_issue
    if user.present? && issue.present? && UserIssueMonth.where(uid: user.id, issue: issue_id).any?
      self.errors.add(:base, I18n.t('worktime.errors.issue_has_allready_bound_to_user', issue_id: issue_id))
    end
  end

  def issue_exists
    unless issue.present?
      self.errors.add(:base, I18n.t('worktime.errors.issue_is_not_exist', issue_id: issue_id))
    end
  end
end
