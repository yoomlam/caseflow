import { associateTasksWithAppeals } from './utils';
import { ACTIONS } from './constants';
import { hideErrorMessage } from './uiReducer/uiActions';
import ApiUtil from '../util/ApiUtil';

export const onReceiveQueue = ({ tasks, appeals, userId }) => ({
  type: ACTIONS.RECEIVE_QUEUE_DETAILS,
  payload: {
    tasks,
    appeals,
    userId
  }
});

export const onReceiveJudges = (judges) => ({
  type: ACTIONS.RECEIVE_JUDGE_DETAILS,
  payload: {
    judges
  }
});

export const setAppealDocCount = (appealId, docCount) => ({
  type: ACTIONS.SET_APPEAL_DOC_COUNT,
  payload: {
    appealId,
    docCount
  }
});

export const setCaseReviewActionType = (type) => ({
  type: ACTIONS.SET_REVIEW_ACTION_TYPE,
  payload: {
    type
  }
});

export const setDecisionOptions = (opts) => (dispatch) => {
  dispatch(hideErrorMessage());
  dispatch({
    type: ACTIONS.SET_DECISION_OPTIONS,
    payload: {
      opts
    }
  });
};

export const resetDecisionOptions = () => ({
  type: ACTIONS.RESET_DECISION_OPTIONS
});

export const editAppeal = (appealId, attributes) => ({
  type: ACTIONS.EDIT_APPEAL,
  payload: {
    appealId,
    attributes
  }
});

export const deleteAppeal = (appealId) => ({
  type: ACTIONS.DELETE_APPEAL,
  payload: {
    appealId
  }
});

export const editStagedAppeal = (appealId, attributes) => ({
  type: ACTIONS.EDIT_STAGED_APPEAL,
  payload: {
    appealId,
    attributes
  }
});

export const stageAppeal = (appealId) => ({
  type: ACTIONS.STAGE_APPEAL,
  payload: {
    appealId
  }
});

export const checkoutStagedAppeal = (appealId) => ({
  type: ACTIONS.CHECKOUT_STAGED_APPEAL,
  payload: {
    appealId
  }
});

export const updateEditingAppealIssue = (attributes) => ({
  type: ACTIONS.UPDATE_EDITING_APPEAL_ISSUE,
  payload: {
    attributes
  }
});

export const startEditingAppealIssue = (appealId, issueId, attributes) => (dispatch) => {
  dispatch({
    type: ACTIONS.START_EDITING_APPEAL_ISSUE,
    payload: {
      appealId,
      issueId
    }
  });

  if (attributes) {
    dispatch(updateEditingAppealIssue(attributes));
  }
};

export const deleteEditingAppealIssue = (appealId, issueId, attributes) => (dispatch) => {
  dispatch({
    type: ACTIONS.DELETE_EDITING_APPEAL_ISSUE,
    payload: {
      appealId,
      issueId
    }
  });
  dispatch(editAppeal(appealId, attributes));
};

export const cancelEditingAppealIssue = () => ({
  type: ACTIONS.CANCEL_EDITING_APPEAL_ISSUE
});

export const saveEditedAppealIssue = (appealId, attributes) => (dispatch) => {
  dispatch({
    type: ACTIONS.SAVE_EDITED_APPEAL_ISSUE,
    payload: {
      appealId
    }
  });

  if (attributes) {
    dispatch(editStagedAppeal(appealId, attributes));
    dispatch(editAppeal(appealId, attributes));
  }
};

export const setAttorneysOfJudge = (attorneys) => ({
  type: ACTIONS.SET_ATTORNEYS_OF_JUDGE,
  payload: {
    attorneys
  }
});

const receiveTasksAndAppealsOfAttorney = ({ attorneyId, tasks, appeals }) => ({
  type: ACTIONS.SET_TASKS_AND_APPEALS_OF_ATTORNEY,
  payload: {
    attorneyId,
    tasks,
    appeals
  }
});

const requestTasksAndAppealsOfAttorney = (attorneyId) => ({
  type: ACTIONS.REQUEST_TASKS_AND_APPEALS_OF_ATTORNEY,
  payload: {
    attorneyId
  }
});

const errorTasksAndAppealsOfAttorney = ({ attorneyId, error }) => ({
  type: ACTIONS.ERROR_TASKS_AND_APPEALS_OF_ATTORNEY,
  payload: {
    attorneyId,
    error
  }
});

export const fetchTasksAndAppealsOfAttorney = (attorneyId) => (dispatch) => {
  const requestOptions = {
    timeout: true
  };

  dispatch(requestTasksAndAppealsOfAttorney(attorneyId));

  return ApiUtil.get(`/queue/${attorneyId}`, requestOptions).then(
    (resp) => dispatch(
      receiveTasksAndAppealsOfAttorney(
        { attorneyId,
          ...associateTasksWithAppeals(JSON.parse(resp.text)) })),
    (error) => dispatch(errorTasksAndAppealsOfAttorney({ attorneyId,
      error }))
  );
};

export const setSelectionOfTaskOfUser = ({ userId, taskId, selected }) => ({
  type: ACTIONS.SET_SELECTION_OF_TASK_OF_USER,
  payload: {
    userId,
    taskId,
    selected
  }
});

const initialTaskAssignment = ({ task, assigneeId }) => ({
  type: ACTIONS.TASK_INITIAL_ASSIGNED,
  payload: {
    task,
    assigneeId
  }
});

export const initialAssignTasksToUser = ({ tasks, assigneeId, previousAssigneeId }) => (dispatch) =>
  Promise.all(tasks.map((oldTask) => {
    return ApiUtil.post(
      '/legacy_tasks',
      { data: { tasks: { assigned_to_id: assigneeId,
        type: 'JudgeCaseAssignmentToAttorney',
        appeal_id: oldTask.attributes.appeal_id } } }).
      then((resp) => resp.body).
      then(
        (resp) => {
          const { task: { data: task } } = resp;

          task.appealId = task.id;
          dispatch(initialTaskAssignment({ task,
            assigneeId }));
          dispatch(setSelectionOfTaskOfUser({ userId: previousAssigneeId,
            taskId: task.id,
            selected: false }));
        });
  }));

const taskReassignment = ({ task, assigneeId, previousAssigneeId }) => ({
  type: ACTIONS.TASK_REASSIGNED,
  payload: {
    task,
    assigneeId,
    previousAssigneeId
  }
});

export const reassignTasksToUser = ({ tasks, assigneeId, previousAssigneeId }) => (dispatch) =>
  Promise.all(tasks.map((oldTask) => {
    return ApiUtil.patch(
      `/legacy_tasks/${oldTask.attributes.task_id}`,
      { data: { tasks: { assigned_to_id: assigneeId } } }).
      then((resp) => resp.body).
      then(
        (resp) => {
          const { task: { data: task } } = resp;

          task.appealId = task.id;
          dispatch(taskReassignment({ task,
            assigneeId,
            previousAssigneeId }));
          dispatch(setSelectionOfTaskOfUser({ userId: previousAssigneeId,
            taskId: task.id,
            selected: false }));
        });
  }));
