describe Appeal do
  context "priority and non-priority appeals" do
    let!(:appeal) { create(:appeal) }
    let!(:aod_age_appeal) { create(:appeal, :advanced_on_docket_due_to_age) }
    let!(:aod_motion_appeal) { create(:appeal, :advanced_on_docket_due_to_motion) }
    let!(:denied_aod_motion_appeal) { create(:appeal, :denied_advance_on_docket) }
    let!(:inapplicable_aod_motion_appeal) { create(:appeal, :inapplicable_aod_motion) }

    context "#all_priority" do
      subject { Appeal.all_priority }
      it "returns aod appeals due to age and motion" do
        expect(subject.include?(aod_age_appeal)).to eq(true)
        expect(subject.include?(aod_motion_appeal)).to eq(true)
        expect(subject.include?(appeal)).to eq(false)
        expect(subject.include?(denied_aod_motion_appeal)).to eq(false)
        expect(subject.include?(inapplicable_aod_motion_appeal)).to eq(false)
      end
    end

    context "#all_nonpriority" do
      subject { Appeal.all_nonpriority }
      it "returns non aod appeals" do
        expect(subject.include?(appeal)).to eq(true)
        expect(subject.include?(aod_motion_appeal)).to eq(false)
        expect(subject.include?(denied_aod_motion_appeal)).to eq(true)
        expect(subject.include?(inapplicable_aod_motion_appeal)).to eq(true)
      end
    end
  end

  context "#document_fetcher" do
    let(:veteran_file_number) { "64205050" }
    let(:appeal) do
      create(:appeal, veteran_file_number: veteran_file_number)
    end

    it "returns a DocumentFetcher" do
      expect(appeal.document_fetcher.appeal).to eq(appeal)
      expect(appeal.document_fetcher.use_efolder).to eq(true)
    end
  end

  context "async logic scopes" do
    let!(:appeal_requiring_processing) do
      create(:appeal).tap(&:submit_for_processing!)
    end

    let!(:appeal_processed) do
      create(:appeal).tap(&:processed!)
    end

    let!(:appeal_recently_attempted) do
      create(
        :appeal,
        establishment_attempted_at: (Appeal::REQUIRES_PROCESSING_RETRY_WINDOW_HOURS - 1).hours.ago
      )
    end

    let!(:appeal_attempts_ended) do
      create(
        :appeal,
        establishment_submitted_at: (Appeal::REQUIRES_PROCESSING_WINDOW_DAYS + 5).days.ago,
        establishment_attempted_at: (Appeal::REQUIRES_PROCESSING_WINDOW_DAYS + 1).days.ago
      )
    end

    context ".unexpired" do
      it "matches appeals still inside the processing window" do
        expect(Appeal.unexpired).to eq([appeal_requiring_processing])
      end
    end

    context ".processable" do
      it "matches appeals eligible for processing" do
        expect(Appeal.processable).to match_array(
          [appeal_requiring_processing, appeal_attempts_ended]
        )
      end
    end

    context ".attemptable" do
      it "matches appeals that could be attempted" do
        expect(Appeal.attemptable).not_to include(appeal_recently_attempted)
      end
    end

    context ".requires_processing" do
      it "matches appeals that must still be processed" do
        expect(Appeal.requires_processing).to eq([appeal_requiring_processing])
      end
    end

    context ".expired_without_processing" do
      it "matches appeals unfinished but outside the retry window" do
        expect(Appeal.expired_without_processing).to eq([appeal_attempts_ended])
      end
    end
  end

  context "#establish!" do
    it { is_expected.to_not be_nil }
  end

  context "#special_issues" do
    let(:appeal) { create(:appeal) }
    let(:vacols_id) { nil }
    let!(:request_issue) do
      create(:request_issue, review_request: appeal, vacols_id: vacols_id)
    end

    subject { appeal.reload.special_issues }

    context "no special conditions" do
      it "is empty" do
        expect(subject).to eq []
      end
    end

    context "VACOLS opt-in" do
      let(:vacols_id) { "something" }
      let!(:legacy_opt_in) do
        create(:legacy_issue_optin, request_issue: request_issue)
      end

      it "includes VACOLS opt-in" do
        expect(subject).to include(code: "VO", narrative: Constants.VACOLS_DISPOSITIONS_BY_ID.O)
      end
    end
  end

  context "#docket_number" do
    context "when receipt_date is defined" do
      let(:appeal) do
        create(:appeal, receipt_date: Time.new("2018", "04", "05").utc)
      end

      it "returns a docket number if receipt_date is defined" do
        expect(appeal.docket_number).to eq("180405-#{appeal.id}")
      end
    end

    context "when receipt_date is nil" do
      let(:appeal) do
        create(:appeal, receipt_date: nil)
      end

      it "returns Missing Docket Number" do
        expect(appeal.docket_number).to eq("Missing Docket Number")
      end
    end
  end

  context "#advanced_on_docket" do
    context "when a claimant is advanced_on_docket" do
      let(:appeal) do
        create(:appeal, claimants: [create(:claimant, :advanced_on_docket_due_to_age)])
      end

      it "returns true" do
        expect(appeal.advanced_on_docket).to eq(true)
      end
    end

    context "when no claimant is advanced_on_docket" do
      let(:appeal) do
        create(:appeal)
      end

      it "returns false" do
        expect(appeal.advanced_on_docket).to eq(false)
      end
    end
  end

  context "#find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id" do
    context "with a uuid (AMA appeal id)" do
      let(:veteran_file_number) { "64205050" }
      let(:appeal) do
        create(:appeal, veteran_file_number: veteran_file_number)
      end

      it "finds the appeal" do
        expect(Appeal.find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id(appeal.uuid)).to \
          eq(appeal)
      end

      it "returns RecordNotFound for a non-existant one" do
        made_up_uuid = "11111111-aaaa-bbbb-CCCC-999999999999"
        expect { Appeal.find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id(made_up_uuid) }.to \
          raise_exception(ActiveRecord::RecordNotFound, "Couldn't find Appeal")
      end
    end

    context "with a legacy appeal" do
      let(:vacols_case) { create(:case) }
      let(:legacy_appeal) do
        create(:legacy_appeal, vacols_case: vacols_case)
      end

      it "finds the appeal" do
        legacy_appeal.save
        expect(Appeal.find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id(legacy_appeal.vacols_id)).to \
          eq(legacy_appeal)
      end

      it "returns RecordNotFound for a non-existant one" do
        made_up_non_uuid = "9876543"
        expect do
          Appeal.find_appeal_by_id_or_find_or_create_legacy_appeal_by_vacols_id(made_up_non_uuid)
        end.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
  end

  context "#appellant_first_name" do
    subject { appeal.appellant_first_name }

    context "when appeal has claimants" do
      let(:appeal) { create(:appeal, number_of_claimants: 1) }

      it "returns claimant's name" do
        expect(subject).to_not eq nil
        expect(subject).to eq appeal.claimants.first.first_name
      end
    end

    context "when appeal doesn't have claimants" do
      let(:appeal) { create(:appeal, number_of_claimants: 0) }

      it { is_expected.to eq nil }
    end
  end

  context "when claimants have different poas" do
    let(:participant_id_with_pva) { "1234" }
    let(:participant_id_with_aml) { "5678" }

    let(:appeal) do
      create(:appeal, claimants: [
               create(:claimant, participant_id: participant_id_with_pva),
               create(:claimant, participant_id: participant_id_with_aml)
             ])
    end

    let!(:vso) do
      Vso.create(
        name: "Paralyzed Veterans Of America",
        role: "VSO",
        url: "paralyzed-veterans-of-america",
        participant_id: "9876"
      )
    end

    before do
      allow_any_instance_of(BGSService).to receive(:fetch_poas_by_participant_ids)
        .with([participant_id_with_pva]).and_return(
          participant_id_with_pva => {
            representative_name: "PARALYZED VETERANS OF AMERICA, INC.",
            representative_type: "POA National Organization",
            participant_id: "9876"
          }
        )
      allow_any_instance_of(BGSService).to receive(:fetch_poas_by_participant_ids)
        .with([participant_id_with_aml]).and_return(
          participant_id_with_aml => {
            representative_name: "AMERICAN LEGION",
            representative_type: "POA National Organization",
            participant_id: "54321"
          }
        )
    end

    context "#power_of_attorney" do
      it "returns the first claimant's power of attorney" do
        expect(appeal.power_of_attorney.representative_name).to eq("PARALYZED VETERANS OF AMERICA, INC.")
      end
    end

    context "#power_of_attorneys" do
      it "returns all claimants power of attorneys" do
        expect(appeal.power_of_attorneys[0].representative_name).to eq("PARALYZED VETERANS OF AMERICA, INC.")
        expect(appeal.power_of_attorneys[1].representative_name).to eq("AMERICAN LEGION")
      end
    end

    context "#vsos" do
      it "returns all vsos this appeal has that exist in our DB" do
        expect(appeal.vsos.count).to eq(1)
        expect(appeal.vsos.first.name).to eq("Paralyzed Veterans Of America")
      end
    end
  end

  context ".create_tasks_on_intake_success!" do
    let(:appeal) do
      create(:appeal)
    end

    it "creates root and vso tasks" do
      expect(RootTask).to receive(:create_root_and_sub_tasks!).once

      appeal.create_tasks_on_intake_success!
    end
  end

  context "#location_code" do
    context "if the RootTask status is completed" do
      let(:appeal) { create(:appeal) }

      before do
        create(:root_task, appeal: appeal, status: :completed)
      end

      it "returns Post-decision" do
        expect(appeal.location_code).to eq(COPY::CASE_LIST_TABLE_POST_DECISION_LABEL)
      end
    end

    context "if there are no active tasks" do
      let(:appeal) { create(:appeal) }
      it "returns nil" do
        expect(appeal.location_code).to eq(nil)
      end
    end

    context "if the only active case is a RootTask" do
      let(:appeal) { create(:appeal) }

      before do
        create(:root_task, appeal: appeal, status: :in_progress)
      end

      it "returns Case storage" do
        expect(appeal.location_code).to eq(COPY::CASE_LIST_TABLE_CASE_STORAGE_LABEL)
      end
    end

    context "if there is an assignee" do
      let(:organization) { create(:organization) }
      let(:appeal_organization) { create(:appeal) }
      let(:user) { create(:user) }
      let(:appeal_user) { create(:appeal) }

      before do
        organization_root_task = create(:root_task, appeal: appeal_organization)
        create(:generic_task, assigned_to: organization, appeal: appeal_organization, parent: organization_root_task)

        user_root_task = create(:root_task, appeal: appeal_user)
        create(:generic_task, assigned_to: user, appeal: appeal_user, parent: user_root_task)
      end

      it "if the most recent assignee is an organization it returns the organization name" do
        expect(appeal_organization.location_code).to eq(organization.name)
      end

      it "if the most recent assignee is not an organization it returns the id" do
        expect(appeal_user.location_code).to eq(user.css_id)
      end
    end
  end

  context "is taskable" do
    context "#assigned_attorney" do
      let(:attorney) { create(:user) }
      let(:appeal) { create(:appeal) }
      let!(:task) { create(:ama_attorney_task, assigned_to: attorney, appeal: appeal) }

      subject { appeal.assigned_attorney }

      it { is_expected.to eq attorney }
    end

    context "#assigned_judge" do
      let(:judge) { create(:user) }
      let(:appeal) { create(:appeal) }
      let!(:task) { create(:ama_judge_task, assigned_to: judge, appeal: appeal) }

      subject { appeal.assigned_judge }

      it { is_expected.to eq judge }
    end
  end

  context ".tasks_for_timeline" do
    context "when there are completed organization tasks with completed child tasks assigned to people" do
      let(:judge) { create(:user) }
      let(:appeal) { create(:appeal) }
      let!(:task) { create(:ama_judge_task, assigned_to: judge, appeal: appeal) }
      let!(:task2) do
        create(:qr_task, appeal: appeal, status: Constants.TASK_STATUSES.completed, assigned_to_type: "Organization")
      end
      let!(:task3) do
        create(:qr_task, assigned_to: judge, appeal: appeal, status: Constants.TASK_STATUSES.completed,
                         parent_id: task2.id)
      end

      subject { appeal.tasks_for_timeline.first }
      it { is_expected.to eq task3 }
    end
    context "when there are completed organization tasks without child tasks" do
      let(:judge) { create(:user) }
      let(:appeal) { create(:appeal) }
      let!(:task) { create(:ama_judge_task, assigned_to: judge, appeal: appeal) }
      let!(:task2) do
        create(:qr_task, appeal: appeal, status: Constants.TASK_STATUSES.completed, assigned_to_type: "Organization")
      end

      subject { appeal.tasks_for_timeline.first }
      it { is_expected.to eq task2 }
    end
  end
end
