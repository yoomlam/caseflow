# frozen_string_literal: true

##
# Task assigned to judge from which they will assign the associated appeal to one of their attorneys by creating a
# task (an AttorneyTask but not any of its subclasses) to draft a decision on the appeal.
# Task is created as a result of case distribution.
# Task should always have a RootTask as its parent.
# Task can one or more AttorneyTask children, one or more ColocatedTask children, or no child tasks at all.
# An open task will result in the case appearing in the Judge Assign View.
#
# Expected parent task: RootTask
#
# Expected child task: JudgeAssignTask can have one or more ColocatedTask children or no child tasks at all.
# Historically, it can have AttorneyTask children, but AttorneyTasks should now be under JudgeDecisionReviewTasks.

class JudgeAssignTask < JudgeTask
  validate :only_open_task_of_type, on: :create,
                                    unless: :skip_check_for_only_open_task_of_type?

  def additional_available_actions(_user)
    [Constants.TASK_ACTIONS.ASSIGN_TO_ATTORNEY.to_h]
  end

  # We used to create AttorneyTasks as children of JudgeAssignTasks when judges assigned cases to attorney (and later
  # changed the type of the JudgeAssignTask to JudgeDecisionReviewTask when the attorney completed the AttorneyTask).
  # Starting on 20 June 2019 (https://github.com/department-of-veterans-affairs/caseflow/pull/11140), we changed to the
  # current behavior, however we still need to support the old behavior since (as of 15 July 2021) there are still 20
  # active AttorneyTasks that are children of JudgeAssignTasks.
  def begin_decision_review_phase
    update!(type: JudgeDecisionReviewTask.name)
  end

  def self.label
    COPY::JUDGE_ASSIGN_TASK_LABEL
  end

  def hide_from_case_timeline
    true
  end
end
