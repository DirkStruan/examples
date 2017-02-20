require_relative '../test_helper'
require_relative './pages/work_time_page'

class WorkTimeIndexTest < ActiveSupport::TestCase
  include IntegrationSpecTest
  include WorkTimePage

  fixtures :users, :projects, :settings, :issues, :time_entries

  let (:user) { users(:users_001) }
  let (:issue) { issues(:issues_001) }
  let (:activity) { TimeEntryActivity.find_or_create_by(id: 9, name: 'Design', type: 'TimeEntryActivity', position: 1, active: true) }
  let (:time_entry) { time_entries(:time_entries_002) }

  # testing values
  let(:valid_comment) { 'test comment' }
  let(:new_time_entry_hours_1) { '4.0' }
  let(:new_time_entry_hours_2) { '8.0' }
  let(:new_time_entry_hours_overtime) { '21.0' }
  let(:missing_comment_message) { I18n.t('activerecord.errors.messages.blank') }
  let(:new_comment) { 'New comment message' }
  let(:increasing_hours_error_message) { I18n.t('activerecord.errors.models.time_entry.attributes.hours.can_not_be_increased') }
  let(:time_track_too_old_error_message) { I18n.t('activerecord.errors.models.time_entry.attributes.base.invalid_checked_date') }
  let(:sl_status_blocked_message) { I18n.t('activerecord.errors.models.time_entry.attributes.base.office_blocked') }
  let(:hours_overtime_message) { I18n.t('activerecord.errors.models.time_entry.attributes.hours.invalid_sum') }
  before do
    log_user('admin', 'admin')
  end

  MiniTest::Unit.after_tests { Timecop.return }

  describe 'visit /work_time/index' do
    describe 'regular user' do
      before do
        # В следующих строчках:
        # - Включаем в настройках проверку вводимых TimeEntry для тестируемого пользователя;
        # - Устанавливаем время time_entry = 5 т.к. в фикстурах установлено 150, чтобы протестировать
        #   попытки увеличить и уменьшить часы.
        Timecop.travel(today)
        Setting.set_from_params(:plugin_redmine_control_time_entry, {
            control_time_entry_enable: '1',
            controlled_erp_offices: %w(1 2 5),
            last_erp_employees_hash: '',
            exclusive_users: []
        })
        time_entry.update_attribute 'hours', 5
        RedmineControlTimeEntry.settings[:control_time_entry_enable] = '1'
        ErpUserDetail.destroy_all
        ErpUserDetail.create!(user_id: user.id, erp_office_id: 1)
        RedmineControlTimeEntry.settings[:controlled_erp_offices] = ['1', '2', '5']
        visit_index
      end

      describe 'today' do
        let(:today) { Date.parse('2007-03-12') }

        it { assert_equal time_entry.hours.round(1).to_s, current_total_time.text }

        describe 'validations' do
          before do
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'allow to change comment text' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { new_comment }

            it { assert_equal time_entry.reload.comments, new_comment }
          end

          describe 'allows to reduce hours' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_1, current_total_time.text }

          end

          describe 'allows to increase hours' do
            let(:hours) { new_time_entry_hours_2 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_2, current_total_time.text }
          end

          describe 'validates hours overtime' do
            let(:hours) { new_time_entry_hours_overtime }
            let(:comments) { valid_comment }

            it { assert_text hours_overtime_message }
          end

          describe 'validates comment presence' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { '' }

            it { assert_text missing_comment_message }
          end
        end

        describe 'sl status blocked' do
          before do
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'does not allow update comment' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_text sl_status_blocked_message }
          end
        end
      end

      describe 'previous day' do
        let(:today) { Date.parse('2007-03-13') }

        before do
          visit_index(today.yesterday)
        end

        it { assert_equal time_entry.hours.round(1).to_s, current_total_time.text }

        describe 'validations' do
          before do
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'allow to change comment text' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { new_comment }

            it { assert_equal time_entry.reload.comments, new_comment }
          end

          describe 'allows to reduce hours' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_1, current_total_time.text }
          end

          describe 'allows to increase hours' do
            let(:hours) { new_time_entry_hours_2 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_2, current_total_time.text }
          end

          describe 'validates hours overtime' do
            let(:hours) { new_time_entry_hours_overtime }
            let(:comments) { valid_comment }

            it { assert_text hours_overtime_message }
          end

          describe 'validates comment presence' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { '' }

            it { assert_text missing_comment_message }
          end
        end

        describe 'sl status blocked' do
          before do
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'does not allow update comment' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_text sl_status_blocked_message }
          end
        end
      end

      describe 'first day of month' do
        let(:today) { Date.parse('2007-03-1') }

        describe 'edit today' do
          let(:day_of_testing) { today }

          describe 'validations' do
            before do
              time_entry.update_attribute('spent_on', day_of_testing)
              visit_index(day_of_testing)
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'allow to change comment text' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { new_comment }

              it { assert_equal time_entry.reload.comments, new_comment }
            end

            describe 'allows to reduce hours' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_1, current_total_time.text }

            end

            describe 'allows to increase hours' do
              let(:hours) { new_time_entry_hours_2 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_2, current_total_time.text }
            end

            describe 'validates hours overtime' do
              let(:hours) { new_time_entry_hours_overtime }
              let(:comments) { valid_comment }

              it { assert_text hours_overtime_message }
            end
          end

          describe 'sl status blocked' do
            before do
              time_entry.update_attribute('spent_on', day_of_testing)
              visit_index(day_of_testing)
              SlCalculationStatus.create(
                  erp_office_id: user.erp_detail.erp_office_id,
                  erp_corporation_id: user.erp_detail.erp_corporation_id,
                  period: Date.today.beginning_of_month,
                  closed: true
              )
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'does not allow update comment' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text sl_status_blocked_message }
            end
          end
        end

        describe 'edit yesterday' do
          let(:day_of_testing) { today - 1.days }

          before do
            time_entry.update_attribute('spent_on', day_of_testing)
            visit_index(day_of_testing)
          end

          describe 'validations' do
            before do
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'allow to change comment text' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { new_comment }

              it { assert_equal time_entry.reload.comments, new_comment }
            end

            describe 'allows to reduce hours' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_1, current_total_time.text }

            end

            describe 'allows to increase hours' do
              let(:hours) { new_time_entry_hours_2 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_2, current_total_time.text }
            end

            describe 'validates hours overtime' do
              let(:hours) { new_time_entry_hours_overtime }
              let(:comments) { valid_comment }

              it { assert_text hours_overtime_message }
            end
          end

          describe 'sl status blocked' do
            before do
              # Поскольку мы редактируем TimeEntry за прошлый месяц - создаем закрытую ведомость за прошлый месяц.
              SlCalculationStatus.create(
                  erp_office_id: user.erp_detail.erp_office_id,
                  erp_corporation_id: user.erp_detail.erp_corporation_id,
                  period: Date.today.beginning_of_month - 1.month,
                  closed: true
              )
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'does not allow update comment' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text sl_status_blocked_message }
            end
          end
        end

        describe 'edit past month' do
          let(:day_of_testing) { today - 2.days }

          before do
            time_entry.update_attribute('spent_on', day_of_testing)
            visit_index(day_of_testing)
          end

          describe 'validations' do
            before do
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'allow to change comment text' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { new_comment }

              it { assert_text(time_track_too_old_error_message) }
            end

            describe 'allows to reduce hours' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }

            end

            describe 'allows to increase hours' do
              let(:hours) { new_time_entry_hours_2 }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }
            end

            describe 'validates hours overtime' do
              let(:hours) { new_time_entry_hours_overtime }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }
            end
          end

          describe 'sl status blocked' do
            before do
              SlCalculationStatus.create(
                  erp_office_id: user.erp_detail.erp_office_id,
                  erp_corporation_id: user.erp_detail.erp_corporation_id,
                  period: Date.today.beginning_of_month,
                  closed: true
              )
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'does not allow update comment' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }
            end
          end
        end
      end

      describe 'more than two days before but in current month' do
        let(:today) { Date.parse('2007-03-14') }

        before do
          visit_index(today - 2.days)
        end

        it { assert_equal time_entry.hours.round(1).to_s, current_total_time.text }

        describe 'validations' do
          before do
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'allow to change comment text' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { new_comment }

            it { assert_equal time_entry.reload.comments, new_comment }
          end

          describe 'allows to reduce hours' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_1, current_total_time.text }
          end

          describe 'does not allows to increase hours' do
            let(:hours) { new_time_entry_hours_2 }
            let(:comments) { valid_comment }

            it { assert_text increasing_hours_error_message }
          end

          describe 'validates hours overtime' do
            let(:hours) { new_time_entry_hours_overtime }
            let(:comments) { valid_comment }

            it { assert_text hours_overtime_message }
          end

          describe 'validates comment presence' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { '' }

            it { assert_text missing_comment_message }
          end
        end

        describe 'sl status blocked' do
          before do
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'does not allow update comment' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_text sl_status_blocked_message }
          end
        end
      end

      describe 'past month day' do
        let(:today) { Date.parse('2007-04-12') }

        before do
          visit_index(today - 1.month)
          set_time_entry_attributes(time_entry, hours: new_time_entry_hours_1, comments: valid_comment)
          submit_changes
        end

        it { assert_not_equal new_time_entry_hours_1, current_total_time.text }
        it { assert_text(time_track_too_old_error_message) }
      end
    end

    describe 'exclusive user' do
      before do
        # Аналогично обычному пользователю, но делаем пользователя эксклюзивным

        Setting.set_from_params(:plugin_redmine_control_time_entry, {
            control_time_entry_enable: '1',
            controlled_erp_offices: %w(1 2 5),
            last_erp_employees_hash: '',
            exclusive_users: [user.id.to_s]
        })
        time_entry.update_attribute 'hours', 5
        RedmineControlTimeEntry.settings[:control_time_entry_enable] = '1'
        ErpUserDetail.destroy_all
        ErpUserDetail.create!(user_id: user.id, erp_office_id: 1)
        RedmineControlTimeEntry.settings[:controlled_erp_offices] = ['1', '2', '5']
        Timecop.travel(today)
        visit_index
      end

      describe 'today' do
        let(:today) { Date.parse('2007-03-12') }

        it { assert_equal time_entry.hours.round(1).to_s, current_total_time.text }

        describe 'validations' do
          before do
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'allow to change comment text' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { new_comment }

            it { assert_equal time_entry.reload.comments, new_comment }
          end

          describe 'allows to reduce hours' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_1, current_total_time.text }
          end

          describe 'allows to increase hours' do
            let(:hours) { new_time_entry_hours_2 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_2, current_total_time.text }
          end

          describe 'validates hours overtime' do
            let(:hours) { new_time_entry_hours_overtime }
            let(:comments) { valid_comment }

            it { assert_text hours_overtime_message }
          end

          describe 'validates comment presence' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { '' }

            it { assert_text missing_comment_message }
          end

        end

        describe 'sl status blocked' do
          before do
            SlCalculationStatus.create(
            erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'does not allow update comment' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_text sl_status_blocked_message }
          end
        end
      end

      describe 'week before' do
        let(:today) { Date.parse('2007-03-19') }
        let(:day_of_testing) { today - 7.days }

        before do
          visit_index(day_of_testing)
        end

        it { assert_equal time_entry.reload.hours.round(1).to_s, current_total_time.text }

        describe 'validations' do
          before do
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'allow to change comment text' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { new_comment }

            it { assert_equal time_entry.reload.comments, new_comment }
          end

          describe 'allows to reduce hours' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_1, current_total_time.text }
          end

          describe 'allows to increase hours' do
            let(:hours) { new_time_entry_hours_2 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_2, current_total_time.text }
          end

          describe 'validates hours overtime' do
            let(:hours) { new_time_entry_hours_overtime }
            let(:comments) { valid_comment }

            it { assert_text hours_overtime_message }
          end

          describe 'validates comment presence' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { '' }

            it { assert_text missing_comment_message }
          end

        end

        describe 'sl status blocked' do
          before do
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'does not allow update comment' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_text sl_status_blocked_message }
          end
        end
      end

      describe 'more than week before but in current month' do
        let(:today) { Date.parse('2007-03-21') }
        let(:day_of_testing) { today - 9.days }

        before do
          visit_index(day_of_testing)
        end

        it { assert_equal time_entry.hours.round(1).to_s, current_total_time.text }

        describe 'validations' do
          before do
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'allow to change comment text' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { new_comment }

            it { assert_equal time_entry.reload.comments, new_comment }
          end

          describe 'allows to reduce hours' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_equal new_time_entry_hours_1, current_total_time.text }
          end

          describe 'does not allows to increase hours' do
            let(:hours) { new_time_entry_hours_2 }
            let(:comments) { valid_comment }

            it { assert_text increasing_hours_error_message }
          end

          describe 'validates hours overtime' do
            let(:hours) { new_time_entry_hours_overtime }
            let(:comments) { valid_comment }

            it { assert_text hours_overtime_message }
          end

          describe 'validates comment presence' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { '' }

            it { assert_text missing_comment_message }
          end
        end

        describe 'sl status blocked' do
          before do
            time_entry.update_attribute('spent_on', day_of_testing)
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
            set_time_entry_attributes(time_entry, hours: hours, comments: comments)
            submit_changes
          end

          describe 'does not allow update comment' do
            let(:hours) { new_time_entry_hours_1 }
            let(:comments) { valid_comment }

            it { assert_text sl_status_blocked_message }
          end
        end
      end

      describe 'first day of month' do
        let(:today) { Date.parse('2007-03-1') }

        describe 'edit today' do
          let(:day_of_testing) { today }

          before do
            time_entry.update_attribute('spent_on', day_of_testing)
            visit_index(day_of_testing)
          end

          describe 'validations' do
            before do
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'allow to change comment text' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { new_comment }

              it { assert_equal time_entry.reload.comments, new_comment }
            end

            describe 'allows to reduce hours' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_1, current_total_time.text }

            end

            describe 'allows to increase hours' do
              let(:hours) { new_time_entry_hours_2 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_2, current_total_time.text }
            end

            describe 'validates hours overtime' do
              let(:hours) { new_time_entry_hours_overtime }
              let(:comments) { valid_comment }

              it { assert_text hours_overtime_message }
            end
          end

          describe 'sl status blocked' do
            before do
              SlCalculationStatus.create(
                  erp_office_id: user.erp_detail.erp_office_id,
                  erp_corporation_id: user.erp_detail.erp_corporation_id,
                  period: Date.today.beginning_of_month,
                  closed: true
              )
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'does not allow update comment' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text sl_status_blocked_message }
            end
          end
        end

        describe 'edit week before' do
          let(:day_of_testing) { today - 7.days }

          describe 'validations' do
            before do
              time_entry.update_attribute('spent_on', day_of_testing)
              visit_index(day_of_testing)
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'allow to change comment text' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { new_comment }

              it { assert_equal time_entry.reload.comments, new_comment }
            end

            describe 'allows to reduce hours' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_1, current_total_time.text }
            end

            describe 'allows to increase hours' do
              let(:hours) { new_time_entry_hours_2 }
              let(:comments) { valid_comment }

              it { assert_equal new_time_entry_hours_2, current_total_time.text }
            end

            describe 'validates hours overtime' do
              let(:hours) { new_time_entry_hours_overtime }
              let(:comments) { valid_comment }

              it { assert_text hours_overtime_message }
            end
          end

          describe 'sl status blocked' do
            before do
              time_entry.update_attribute('spent_on', day_of_testing)
              visit_index(day_of_testing)
              # Поскольку мы редактируем TimeEntry за прошлый месяц - создаем закрытую ведомость за прошлый месяц.
              SlCalculationStatus.create(
                  erp_office_id: user.erp_detail.erp_office_id,
                  erp_corporation_id: user.erp_detail.erp_corporation_id,
                  period: Date.today.beginning_of_month - 1.month,
                  closed: true
              )
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'does not allow update comment' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text sl_status_blocked_message }
            end
          end
        end

        describe 'edit past month' do
          let(:day_of_testing) { today - 9.days }

          before do
            time_entry.update_attribute('spent_on', day_of_testing)
            visit_index(day_of_testing)
          end

          describe 'validations' do
            before do
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'allow to change comment text' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { new_comment }

              it { assert_text(time_track_too_old_error_message) }
            end

            describe 'allows to reduce hours' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }

            end

            describe 'allows to increase hours' do
              let(:hours) { new_time_entry_hours_2 }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }
            end

            describe 'validates hours overtime' do
              let(:hours) { new_time_entry_hours_overtime }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }
            end
          end

          describe 'sl status blocked' do
            before do
              SlCalculationStatus.create(
                  erp_office_id: user.erp_detail.erp_office_id,
                  erp_corporation_id: user.erp_detail.erp_corporation_id,
                  period: Date.today.beginning_of_month,
                  closed: true
              )
              set_time_entry_attributes(time_entry, hours: hours, comments: comments)
              submit_changes
            end

            describe 'does not allow update comment' do
              let(:hours) { new_time_entry_hours_1 }
              let(:comments) { valid_comment }

              it { assert_text(time_track_too_old_error_message) }
            end
          end
        end
      end

      describe 'past month day' do
        let(:today) { Date.parse('2007-04-12') }

        before do
          visit_index(today - 1.month)
          set_time_entry_attributes(time_entry, hours: new_time_entry_hours_1, comments: valid_comment)
          submit_changes
        end

        it { assert_not_equal new_time_entry_hours_1, current_total_time.text }
        it { assert_text(time_track_too_old_error_message) }
      end
    end
  end
end
