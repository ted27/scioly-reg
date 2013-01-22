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
      tournament.reload.is_current.should be_true
    end

    it 'sets other tournaments at the same school to inactive' do
      tournament.set_current
      current_tournament.reload.is_current.should be_false
    end

    it "doesn't change tournaments for other schools" do
      tournament.set_current
      current_tournament_at_another_school.is_current.should be_true
    end
  end

  describe '#has_registration_begun?' do
    let!(:school) { FactoryGirl.create(:school) }
    let!(:tournament) { FactoryGirl.create(:current_tournament, :school => school) }

    context 'when it is before the registration begins' do
      it 'returns false' do
        pretend_now_is(tournament.registration_begins - 1.second) do
          tournament.has_registration_begun?.should be_false
        end
      end
    end
    context 'when registration has started' do
      it 'returns true' do
        pretend_now_is(tournament.registration_begins + 1.second) do
          tournament.has_registration_begun?.should be_true
        end
      end
    end
  end

  describe '#has_registration_ended?' do
    let!(:school) { FactoryGirl.create(:school) }
    let!(:tournament) { FactoryGirl.create(:current_tournament, :school => school) }

    context 'when it is before the registration ends' do
      it 'returns false' do
        pretend_now_is(tournament.registration_ends - 1.second) do
          tournament.has_registration_ended?.should be_false
        end
      end
    end
    context 'when registration has ended' do
      it 'returns true' do
        pretend_now_is(tournament.registration_ends + 1.second) do
          tournament.has_registration_ended?.should be_true
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
      tournament.can_register?.should be_true
    end

    it 'returns false when registration has not begun' do
      tournament.stubs(:has_registration_begun?).returns(false)
      tournament.can_register?.should be_false
    end

    it 'returns false when registration has ended' do
      tournament.stubs(:has_registration_ended?).returns(true)
      tournament.can_register?.should be_false
    end
  end
end