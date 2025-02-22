require 'spec_helper'

describe Tournament do
  describe '#set_current' do
    let!(:school) { FactoryGirl.create(:school) }
    let!(:tournament) { FactoryGirl.create(:tournament, :school => school) }
    let!(:current_tournament) { FactoryGirl.create(:current_tournament, :school => school) }
    let!(:current_tournament_at_another_school) do
      FactoryGirl.create(:current_tournament)
    end

    it 'sets the desired tournament to active' do
      tournament.set_current
      tournament.reload.is_current.should be_truthy
    end

    it 'sets other tournaments at the same school to inactive' do
      tournament.set_current
      current_tournament.reload.is_current.should be_falsy
    end

    it "doesn't change tournaments for other schools" do
      tournament.set_current
      current_tournament_at_another_school.is_current.should be_truthy
    end

    it 'does nothing if the tournament is already current' do
      current_tournament.set_current
      current_tournament.reload.should be_current
    end
  end

  describe '#has_registration_begun?' do
    let!(:school) { FactoryGirl.create(:school) }
    let!(:tournament) { FactoryGirl.create(:current_tournament, :school => school) }

    context 'when it is before the registration begins' do
      it 'returns false' do
        Timecop.freeze(tournament.registration_begins - 1.second) do
          tournament.has_registration_begun?.should be_falsy
        end
      end
    end
    context 'when registration has started' do
      it 'returns true' do
        Timecop.freeze(tournament.registration_begins + 1.second) do
          tournament.has_registration_begun?.should be_truthy
        end
      end
    end
  end

  describe '#has_registration_ended?' do
    let!(:school) { FactoryGirl.create(:school) }
    let!(:tournament) { FactoryGirl.create(:current_tournament, :school => school) }

    context 'when it is before the registration ends' do
      it 'returns false' do
        Timecop.freeze(tournament.registration_ends - 1.second) do
          tournament.has_registration_ended?.should be_falsy
        end
      end
    end
    context 'when registration has ended' do
      it 'returns true' do
        Timecop.freeze(tournament.registration_ends + 1.second) do
          tournament.has_registration_ended?.should be_truthy
        end
      end
    end
  end

  describe '#can_register?' do
    let!(:school) { FactoryGirl.create(:school) }
    let!(:tournament) { FactoryGirl.create(:current_tournament, :school => school) }

    it 'returns true when registration has begun but not ended' do
      tournament.stubs(:has_registration_begun?).returns(true)
      tournament.stubs(:has_registration_ended?).returns(false)
      tournament.can_register?.should be_truthy
    end

    it 'returns false when registration has not begun' do
      tournament.stubs(:has_registration_begun?).returns(false)
      tournament.can_register?.should be_falsy
    end

    it 'returns false when registration has ended' do
      tournament.stubs(:has_registration_ended?).returns(true)
      tournament.can_register?.should be_falsy
    end
  end

  describe '#load_default_events' do
    let!(:tournament) { FactoryGirl.create(:current_tournament) }
    let!(:default_event) { FactoryGirl.create(:default_event, :year => tournament.date.year) }
    let!(:default_event_other_year) { FactoryGirl.create(:default_event, :year => tournament.date.year + 1) }

    it 'loads default events for that year' do
      tournament.load_default_events
      tournament.schedules.reload.pluck(:event).should == [ default_event.name ]
    end
  end

  describe '#human_times' do
    let(:tournament) { FactoryGirl.create(:tournament) }

    # Keep us in UTC to guard against when Time.zone has not been set
    around { |ex| Time.use_zone('UTC', &ex) }

    it 'converts to school timezone' do
      times = tournament.human_times
      zone = tournament.school.time_zone

      begins_local = tournament.registration_begins.in_time_zone(zone).strftime('%I:%M %p')
      expect(times[:registration_begins]).to include(begins_local)

      ends_local = tournament.registration_ends.in_time_zone(zone).strftime('%I:%M %p')
      expect(times[:registration_ends]).to include(ends_local)
    end
  end
end
