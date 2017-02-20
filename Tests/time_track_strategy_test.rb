require File.expand_path('../../test_helper', __FILE__)

class TimeTrackStrategyTest < ActiveSupport::TestCase
  fixtures :users, :projects, :settings, :issues, :time_entries

  let (:user) { users(:users_003) }
  let (:issue) { issues(:issues_001) }
  let (:friday) { Date.parse('2007-03-23') }
  let (:monday) { Date.parse('2007-03-26') }
  let (:tuesday) { Date.parse('2007-03-27') }
  let (:activity) { TimeEntryActivity.find_or_create_by(id: 9, name: 'Design', type: 'TimeEntryActivity', position: 1, active: true) }

  MiniTest::Unit.after_tests { Timecop.return }

  describe 'on update' do
    let(:time_entry) { time_entries(:time_entries_001) }
    let(:user) { time_entry.user }

    before do
      Setting.set_from_params(:plugin_redmine_control_time_entry, {
          control_time_entry_enable: '1',
          controlled_erp_offices: %w(1),
          last_erp_employees_hash: '',
          exclusive_users: []
      })
      RedmineControlTimeEntry.settings[:control_time_entry_enable] = '1'
      ErpUserDetail.destroy_all
      ErpUserDetail.create!(user_id: user.id, erp_office_id: 1)
      RedmineControlTimeEntry.settings[:controlled_erp_offices] = %w(1)
      Timecop.travel(day_of_testing)
      @time_entry = TimeEntry.find(time_entry.id)
      @time_entry.update_attribute('spent_on', spent_on_day)
      @time_entry.reload.assign_attributes(update_attributes)
    end

    describe 'update today' do
      let(:day_of_testing) { tuesday }
      let(:spent_on_day) { day_of_testing }

      describe 'edit attributes' do
        let(:update_attributes) { { comments: 'Another comment' } }

        it { assert_equal true, @time_entry.save }
      end

      describe 'reduce time entry hours' do
        let(:update_attributes) { { hours: time_entry.hours - 0.1 } }

        it { assert_equal true, @time_entry.save }
      end

      describe 'increase time entry hours' do
        let(:update_attributes) { { hours: time_entry.hours + 0.1 } }

        it { assert_equal true, @time_entry.save }
      end

      describe 'overtime' do
        let(:update_attributes) { { hours: 21 } }

        it { assert_equal false, @time_entry.save }
      end

      describe 'spent day missing' do
        let(:update_attributes) { { spent_on: nil } }

        it { assert_equal false, @time_entry.save }
      end

      describe 'modify day to invalid date' do
        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: Date.today.yesterday - 10.days } }

          it { assert_equal false, @time_entry.save }
        end
      end


      describe 'modify day to valid date' do
        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: Date.today.yesterday } }

          it { assert_equal true, @time_entry.save }
        end
      end

      describe 'sl status blocked' do
        let(:update_attributes) { { comments: 'Another comment' } }

        before do
          SlCalculationStatus.create(
            erp_office_id: user.erp_detail.erp_office_id,
            erp_corporation_id: user.erp_detail.erp_corporation_id,
            period: Date.today.beginning_of_month,
            closed: true
          )
        end

        it { assert_equal false, @time_entry.save }
      end
    end

    describe 'update day from current month' do
      let(:day_of_testing) { tuesday }
      let(:spent_on_day) { day_of_testing.beginning_of_month }

      describe 'edit attributes' do
        let(:update_attributes) { { comments: 'Another comment' } }

        it { assert_equal true, @time_entry.save }
      end

      describe 'reduce time entry hours' do
        let(:update_attributes) { { hours: time_entry.hours - 0.1 } }

        it { assert_equal true, @time_entry.save }
      end

      describe 'increase time entry hours' do
        let(:update_attributes) { { hours: time_entry.hours + 0.1 } }

        it { assert_equal false, @time_entry.save }
      end

      describe 'increase time entry hours by small time' do
        let(:update_attributes) { { hours: time_entry.hours + 0.004 } }

        it { assert_equal true, @time_entry.save }
      end

      describe 'modify day to invalid date' do
        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: Date.today.yesterday - 10.days } }

          it { assert_equal false, @time_entry.save }
        end
      end

      describe 'modify day to valid date' do
        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: Date.today.yesterday } }

          it { assert_equal true, @time_entry.save }
        end
      end

      describe 'sl status blocked' do
        let(:update_attributes) { { comments: 'Another comment' } }

        before do
          SlCalculationStatus.create(
              erp_office_id: user.erp_detail.erp_office_id,
              erp_corporation_id: user.erp_detail.erp_corporation_id,
              period: Date.today.beginning_of_month,
              closed: true
          )
        end

        it { assert_equal false, @time_entry.save }
      end
    end

    describe 'update day from previous month' do
      let(:day_of_testing) { Date.new(2007, 4, 4) }
      let(:spent_on_day) { day_of_testing.beginning_of_month - 1.day }

      describe 'edit attributes' do
        let(:update_attributes) { { comments: 'Another comment' } }

        it { assert_equal false, @time_entry.save }
      end

      describe 'reduce time entry hours' do
        let(:update_attributes) { { hours: time_entry.hours - 0.1 } }

        it { assert_equal false, @time_entry.save }
      end

      describe 'modify day to days those can be mofidied with restriction' do
        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: Date.today.yesterday - 10.days } }

          it { assert_equal false, @time_entry.save }
        end
      end

      describe 'modify day to days those can be mofidied without restriction' do
        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: Date.today.yesterday } }

          it { assert_equal false, @time_entry.save }
        end
      end

      describe 'increase time entry hours' do
        let(:update_attributes) { { hours: time_entry.hours + 0.1 } }

        it { assert_equal false, @time_entry.save }
      end
    end

    describe 'first day of month' do
      let(:day_of_testing) { tuesday.beginning_of_month  }

      describe 'today' do
        let(:spent_on_day) { day_of_testing }

        describe 'edit attributes' do
          let(:update_attributes) { { comments: 'Another comment' } }

          it { assert_equal true, @time_entry.save }
        end

        describe 'reduce time entry hours' do
          let(:update_attributes) { { hours: time_entry.hours - 0.1 } }

          it { assert_equal true, @time_entry.save }
        end

        describe 'increase time entry hours' do
          let(:update_attributes) { { hours: time_entry.hours + 0.1 } }

          it { assert_equal true, @time_entry.save }
        end

        describe 'overtime' do
          let(:update_attributes) { { hours: 21 } }

          it { assert_equal false, @time_entry.save }
        end

        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: nil } }

          it { assert_equal false, @time_entry.save }
        end

        describe 'sl status blocked' do
          let(:update_attributes) { { comments: 'Another comment' } }

          before do
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: Date.today.beginning_of_month,
                closed: true
            )
          end

          it { assert_equal false, @time_entry.save }
        end
      end

      describe 'previous month day' do
        let(:spent_on_day) { day_of_testing.yesterday }

        describe 'edit attributes' do
          let(:update_attributes) { { comments: 'Another comment' } }

          it { assert_equal true, @time_entry.save }
        end

        describe 'reduce time entry hours' do
          let(:update_attributes) { { hours: time_entry.hours - 0.1 } }

          it { assert_equal true, @time_entry.save }
        end

        describe 'increase time entry hours' do
          let(:update_attributes) { { hours: time_entry.hours + 0.1 } }

          it { assert_equal true, @time_entry.save }
        end

        describe 'overtime' do
          let(:update_attributes) { { hours: 21 } }

          it { assert_equal false, @time_entry.save }
        end

        describe 'spent day missing' do
          let(:update_attributes) { { spent_on: nil } }

          it { assert_equal false, @time_entry.save }
        end

        describe 'sl status blocked' do
          let(:update_attributes) { { comments: 'Another comment' } }

          before do
            # Поскольку мы редактируем TimeEntry за прошлый месяц - создаем закрытую ведомость за прошлый месяц.
            SlCalculationStatus.create(
                erp_office_id: user.erp_detail.erp_office_id,
                erp_corporation_id: user.erp_detail.erp_corporation_id,
                period: (Date.today - 1.month).beginning_of_month,
                closed: true
            )
          end

          it { assert_equal false, @time_entry.save }
        end
      end
    end
  end

  def create_time_entry(opts={})
    TimeEntry.create(
      { user: user,
        project: issue.project,
        hours: 3,
        activity_id: activity.id,
        spent_on: 1.month.ago,
        comments: 'test1',
        issue: issue
      }.merge(opts)
    )
  end

end
