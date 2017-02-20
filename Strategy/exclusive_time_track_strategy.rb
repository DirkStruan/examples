class ExclusiveTimeTrackStrategy < TimeTrackStrategy

  ALLOWED_WORK_DAYS_DISTANCE = 5

  def track_day_too_away?
    today = Date.today

    unless @track_day > today or [today, today.yesterday].include? @track_day
      return work_days_between_dates(@track_day, today) > ALLOWED_WORK_DAYS_DISTANCE
    end
    false
  end

  private

  def validate_new_record_spent_on
    if @office.present? && track_day_too_away? && modify_time_track_with_restriction? && hours_increased? && @time_entry.new_record?
      @time_entry.errors.add :base, :track_day_too_away_exclusive
    end
  end

  def validate_existing_record_spent_on_modification
    if @office.present? && track_day_too_away? && modify_time_track_with_restriction? && !@time_entry.new_record? && @time_entry.attribute_changed?(:spent_on)
      @time_entry.errors.add :base, :track_day_too_away_exclusive
    end
  end
end
