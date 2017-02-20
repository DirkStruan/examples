class Employees::ShareProcessor
  attr_reader :employee_ids, :author, :new_employee_ids_for_leads, :team_lead_ids

  def initialize(team_lead_ids = [], employee_ids = [], author = nil)
    @team_lead_ids = select_present_or_default(team_lead_ids)
    @employee_ids = select_present_or_default(employee_ids)
    @author = author || User.robot
    @new_employee_ids_for_leads = calculate_new_employee_ids_for_leads
  end

  def perform_group
    create_shares_for_leads
    notify
  end

  def perform_single
    delete_extra_employee_shares
    create_shares_for_leads
    notify
  end

  def emailed_leads
    @new_employee_ids_for_leads.keys
  end

  private

  def notify
    ActiveSupport::Notifications.instrument 'employee.share', processor: self
  end

  def create_shares_for_leads
    @new_employee_ids_for_leads.each do |team_lead_id, new_employee_ids|
      new_employee_shares_attributes = new_employee_ids.map { |employee_id| [team_lead_id, @author.id, employee_id] }
      EmployeeShare.import([:user_id, :author_id, :employee_id], new_employee_shares_attributes)
    end
  end

  def delete_extra_employee_shares
    EmployeeShare.where(employee_id: @employee_ids)
                 .where.not(user_id: @team_lead_ids)
                 .update_all(destroyed_at: DateTime.current, destroyer_id: @author.id)
  end

  def calculate_new_employee_ids_for_leads
    shared_employees = @team_lead_ids.map { |team_lead_id| [team_lead_id, @employee_ids] }.to_h
    EmployeeShare.where(user_id: @team_lead_ids)
                 .pluck(:user_id, :employee_id)
                 .each { |user_id, employee_id| shared_employees[user_id] -= [employee_id] }
    shared_employees.select { |_user_id, employee_ids| employee_ids.present? }
  end

  def select_present_or_default(value)
    value.present? && value.is_a?(Enumerable) ? value.select(&:presence).map(&:to_i) : []
  end
end
