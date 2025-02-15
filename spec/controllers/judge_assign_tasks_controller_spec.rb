# frozen_string_literal: true

RSpec.describe JudgeAssignTasksController, :all_dbs do
  describe "POST /judge_assign_tasks" do
    let!(:attorney) { create(:user) }
    let!(:judge) { create(:user) }
    let!(:user) { judge }
    let!(:second_judge) { create(:user) }
    let!(:attorney_staff) { create(:staff, :attorney_role, sdomainid: attorney.css_id) }
    let!(:judge_staff) { create(:staff, :judge_role, sdomainid: judge.css_id) }
    let!(:second_judge_staff) { create(:staff, :judge_role, sdomainid: second_judge.css_id) }

    let!(:assign_tasks) do
      Array.new(3) { create(:ama_judge_assign_task, assigned_to: judge, parent: create(:root_task)) }
    end
    let!(:assignee) { attorney }
    let!(:params) do
      assign_tasks.map do |assign_task|
        {
          external_id: assign_task.appeal.external_id,
          parent_id: assign_task.id,
          assigned_to_id: assignee.id
        }
      end
    end

    before { User.authenticate!(user: user) }

    subject { post :create, params: { tasks: params } }

    context "when cases will be assigned to an attorney" do
      shared_examples "attorney task assignment" do
        it "returns the newly created tasks along with their new parents and old parents" do
          subject

          expect(response.status).to eq 200
          response_body = JSON.parse(response.body)["tasks"]["data"]
          expect(response_body.count).to eq 9

          attorney_tasks = response_body.select { |task| task["attributes"]["type"].eql? AttorneyTask.name }
          expect(attorney_tasks.count).to eq 3
          attorney_tasks.each do |attorney_task|
            expect(attorney_task["attributes"]["assigned_to"]["id"]).to eq attorney.id
            expect(attorney_task["attributes"]["assigned_by"]["pg_id"]).to eq user.id
            expect(attorney_task["attributes"]["status"]).to eq Constants.TASK_STATUSES.assigned
            expect(AttorneyTask.find(attorney_task["id"]).parent.type).to eq JudgeDecisionReviewTask.name
          end

          review_tasks = response_body.select { |task| task["attributes"]["type"].eql? JudgeDecisionReviewTask.name }
          expect(review_tasks.count).to eq 3
          review_tasks.each do |review_task|
            judge_review_task = JudgeDecisionReviewTask.find(review_task["id"])
            expect(review_task["attributes"]["assigned_to"]["id"]).to eq judge.id
            expect(review_task["attributes"]["assigned_by"]["pg_id"]).to eq user.id
            expect(judge_review_task.children.first.type).to eq AttorneyTask.name
            expect(judge_review_task.reload.status).to eq Constants.TASK_STATUSES.on_hold
          end

          assign_tasks = response_body.select { |task| task["attributes"]["type"].eql? JudgeAssignTask.name }
          expect(assign_tasks.count).to eq 3
          expect(assign_tasks.all? do |assign_task|
            assign_task["attributes"]["status"].eql? Constants.TASK_STATUSES.completed
          end).to eq true
        end
      end

      it_behaves_like "attorney task assignment"

      context "when the assigner is a member of the scm team" do
        let(:user) { create(:user) }

        before { SpecialCaseMovementTeam.singleton.add_user(user) }

        it_behaves_like "attorney task assignment"
      end

      context "when the assignment encounters an error" do
        before { create(:ama_judge_decision_review_task, assigned_to: judge, parent: assign_tasks.last.parent) }

        it "Returns an error and creates no tasks" do
          subject

          expect(response.status).to eq 400
          expect(JudgeAssignTask.open.count).to eq assign_tasks.count
          expect(JudgeDecisionReviewTask.open.count).to eq 1
          expect(AttorneyTask.open.count).to eq 0
        end
      end
    end

    context "when cases will be assigned to an acting judge" do
      let!(:second_judge_staff) { create(:staff, :attorney_judge_role, sdomainid: second_judge.css_id) }
      let!(:assignee) { second_judge }

      it "returns the newly created tasks" do
        subject

        expect(response.status).to eq 200
        response_body = JSON.parse(response.body)["tasks"]["data"]

        attorney_tasks = response_body.select { |task| task["attributes"]["type"].eql? AttorneyTask.name }
        expect(attorney_tasks.count).to eq 3
        attorney_tasks.each do |attorney_task|
          expect(attorney_task["attributes"]["assigned_to"]["id"]).to eq second_judge.id
        end
      end
    end

    context "when attempting to assign cases to a judge" do
      let!(:assignee) { second_judge }

      it "raises an error" do
        expect { subject }.to raise_error do |error|
          expect(error).to be_a(ActiveRecord::RecordInvalid)
          expect(error.message).to eq("Validation failed: Assigned to has to be an attorney")
        end
      end
    end
  end
end
