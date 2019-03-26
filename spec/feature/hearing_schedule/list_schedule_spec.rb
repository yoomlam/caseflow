# frozen_string_literal: true

require "rails_helper"

RSpec.feature "List Schedule" do
  context "Correct buttons are displayed based on permissions" do
    let!(:hearing) { create(:hearing) }

    context "Build hearing schedule permissions" do
      let!(:current_user) { User.authenticate!(css_id: "BVATWARNER", roles: ["Build HearSched"]) }

      scenario "All buttons are visible" do
        visit "hearings/schedule"

        expect(page).to have_content(COPY::HEARING_SCHEDULE_VIEW_PAGE_HEADER)
        expect(page).to have_content("Schedule Veterans")
        expect(page).to have_content("Build Schedule")
        expect(page).to have_content("Add Hearing Date")
      end
    end

    context "Edit hearing schedule permissions" do
      let!(:current_user) { User.authenticate!(css_id: "BVATWARNER", roles: ["Edit HearSched"]) }

      scenario "Only schedule veterans is available" do
        visit "hearings/schedule"

        expect(page).to have_content(COPY::HEARING_SCHEDULE_VIEW_PAGE_HEADER)
        expect(page).to have_content("Schedule Veterans")
        expect(page).to_not have_content("Build Schedule")
        expect(page).to_not have_content("Add Hearing Date")
      end
    end

    context "View hearing schedule permissions" do
      let!(:current_user) { User.authenticate!(css_id: "BVATWARNER", roles: ["RO ViewHearSched"]) }

      scenario "No buttons are visible" do
        visit "hearings/schedule"

        expect(page).to have_content(COPY::HEARING_SCHEDULE_VIEW_PAGE_HEADER_NONBOARD_USER)
        expect(page).to_not have_content("Schedule Veterans")
        expect(page).to_not have_content("Build Schedule")
        expect(page).to_not have_content("Add Hearing Date")
      end
    end

    context "VSO permissions" do
      let!(:current_user) { User.authenticate!(css_id: "BVATWARNER", roles: ["VSO"]) }

      scenario "No buttons are visible" do
        visit "hearings/schedule"

        expect(page).to have_content(COPY::HEARING_SCHEDULE_VIEW_PAGE_HEADER_NONBOARD_USER)
        expect(page).to_not have_content("Schedule Veterans")
        expect(page).to_not have_content("Build Schedule")
        expect(page).to_not have_content("Add Hearing Date")
      end
    end
  end

  context "VSO user view" do
    let!(:judge_one) { create(:user, full_name: "Judge One") }
    let!(:judge_two) { create(:user, full_name: "Judge Two") }
    let!(:hearing_day_one) { create(:hearing_day, judge: judge_one) }
    let!(:hearing_day_two) { create(:hearing_day, judge: judge_two) }
    let!(:hearing_one) { create(:hearing, :with_tasks, hearing_day: hearing_day_one) }
    let!(:hearing_two) { create(:hearing, :with_tasks, hearing_day: hearing_day_two) }
    let!(:vso_participant_id) { "789" }
    let!(:vso) { create(:vso, participant_id: vso_participant_id) }
    let!(:current_user) { User.authenticate!(css_id: "VSO_USER", roles: ["VSO"]) }
    let!(:track_veteran_task) { create(:track_veteran_task, appeal: hearing_one.appeal, assigned_to: vso) }
    let!(:vso_participant_ids) do
      [
        {
          legacy_poa_cd: "070",
          nm: "VIETNAM VETERANS OF AMERICA",
          org_type_nm: "POA National Organization",
          ptcpnt_id: vso_participant_id
        }
      ]
    end

    before do
      BGSService = ExternalApi::BGSService
      RequestStore[:current_user] = current_user

      allow_any_instance_of(BGS::SecurityWebService).to receive(:find_participant_id)
        .with(css_id: current_user.css_id, station_id: current_user.station_id).and_return(vso_participant_id)
      allow_any_instance_of(BGS::OrgWebService).to receive(:find_poas_by_ptcpnt_id)
        .with(vso_participant_id).and_return(vso_participant_ids)
    end

    after do
      BGSService = Fakes::BGSService
    end

    scenario "Only hearing days with VSO assigned hearings are displayed" do
      OrganizationsUser.add_user_to_organization(current_user, vso)

      visit "hearings/schedule"

      expect(page).to have_content("One, Judge")
      expect(page).to_not have_content("Two, Judge")
    end
  end
end
