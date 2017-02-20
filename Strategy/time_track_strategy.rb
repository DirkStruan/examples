class TimeTrackStrategy

  MAX_HOURS_PER_DAY = 20

  def initialize(time_track)
    @time_entry = time_track
    @user = time_track.user
    @office = @user.erp_detail
    @track_day = time_track.spent_on
  end

  def process!
    validate_sl_blocked
    validate_hours_ovetime
    if track_control_enabled_for_user?
      validate_track_day_in_future
      validate_track_day_missing
      validate_track_day_in_past_month
      validate_hour_changing
      validate_new_record_spent_on
      validate_existing_record_spent_on_modification
      validate_past_month_record_spent_on_modification
    end
  end

  def sl_status_blocked?
    return false unless @office
    sl_calc = SlCalculationStatus.where(
      erp_office_id: @office.erp_office_id,
      erp_corporation_id: @office.erp_corporation_id,
      period: [@time_entry.spent_on.beginning_of_month, @time_entry.spent_on_was.try(:beginning_of_month)]
    ).first
    sl_calc.present? ? sl_calc.closed : false
  end

  private

  def validate_sl_blocked
    if sl_status_blocked?
      @time_entry.errors.add :base, :office_blocked
    end
  end

  def validate_hours_ovetime
    if daily_hours_overtime?
      @time_entry.errors.add :hours, :invalid_sum
    end
  end

  def validate_track_day_in_future
    if @track_day >= date_in_office(1.days.from_now)
      @time_entry.errors.add :spent_on, :track_day_can_not_be_in_future
    end
  end

  def validate_track_day_missing
    if !@track_day.present?
      @time_entry.errors.add :spent_on, :track_day_missing
    end
  end

  def validate_track_day_in_past_month
    if @office.present? && track_day_too_away? && !modify_time_track_with_restriction?
      @time_entry.errors.add :base, :invalid_checked_date
    end
  end

  def validate_hour_changing
    if @office.present? && track_day_too_away? && modify_time_track_with_restriction? && hours_increased? && !@time_entry.new_record?
      @time_entry.errors.add :hours, :can_not_be_increased
    end
  end

  def validate_new_record_spent_on
    if @office.present? && track_day_too_away? && modify_time_track_with_restriction? && hours_increased? && @time_entry.new_record?
      @time_entry.errors.add :base, :track_day_too_away
    end
  end

  def validate_existing_record_spent_on_modification
    if @office.present? && track_day_too_away? && modify_time_track_with_restriction? && !@time_entry.new_record? && @time_entry.attribute_changed?(:spent_on)
      @time_entry.errors.add :base, :track_day_too_away
    end
  end

  def validate_past_month_record_spent_on_modification
    if !@time_entry.new_record? && (@time_entry.spent_on_was < Date.today.beginning_of_month) && @time_entry.attribute_changed?(:spent_on)
      @time_entry.errors.add :base, :invalid_checked_date
    end
  end

  def hours_increased?
    @time_entry.hours.present? && (@time_entry.hours.round(2) > @time_entry.hours_was.to_f.round(2))
  end

  def modify_time_track_with_restriction?
    @modify_time_track_with_restriction ||= @track_day.month == Date.today.month
  end

  def track_control_enabled_for_user?
    @track_control_enabled_for_user ||= begin
      RedmineControlTimeEntry.settings[:control_time_entry_enable] == '1' &&
      @office && RedmineControlTimeEntry.settings[:controlled_erp_offices].to_a.include?(@office.erp_office_id.to_s)
    end
  end

  def track_day_too_away?
    @track_day_too_away ||= begin
      today = Date.today

      unless @track_day > today or [today, today.yesterday].include? @track_day
        return work_days_between_dates(@track_day, today) != 0
      end
      false
    end
  end

  def daily_hours_overtime?
    if @time_entry.id
      current_time_entry = TimeEntry.find(@time_entry.id)
      (TimeEntry.where(user_id: @time_entry.user_id, spent_on: @time_entry.spent_on).sum(:hours) - current_time_entry.hours + @time_entry.hours) > MAX_HOURS_PER_DAY
    else
      (TimeEntry.where(user_id: @time_entry.user_id, spent_on: @time_entry.spent_on).sum(:hours) + @time_entry.hours) > MAX_HOURS_PER_DAY
    end
  end

  def date_in_office(date)
    OFFICES_TIME_ZONES[@user.office_id] ? date.in_time_zone(OFFICES_TIME_ZONES[@user.office_id]).to_date : date.to_date
  end

  def is_working_day?(day, erp_detail)
    return false if day.sunday? or day.saturday?
    ErpHoliday.where(erp_office_id: erp_detail.erp_office_id, date: day, day_type: 'paid').empty?
  end

  def work_days_between_dates(date_from, date_to)
    (date_from.tomorrow..date_to.yesterday).count{ |day| is_working_day?(day, @office) }
  end

end
