// shared functions between reducers
import { ACTIONS } from '../constants';
import { update } from '../../util/ReducerUtil';
import _ from 'lodash';

export const commonReducers = (state, action) => {
  let actionsMap = {};

  actionsMap[ACTIONS.TOGGLE_ADD_ISSUES_MODAL] = () => {
    return update(state, {
      $toggle: ['addIssuesModalVisible']
    });
  };

  actionsMap[ACTIONS.ADD_ISSUE] = () => {
    let listOfIssues = state.addedIssues ? state.addedIssues : [];
    let addedIssues = [...listOfIssues, {
      isRated: action.payload.isRated,
      id: action.payload.issueId,
      profileDate: action.payload.profileDate,
      notes: action.payload.notes
    }];

    return {
      ...state,
      addedIssues,
      issueCount: addedIssues.length
    };
  };

  actionsMap[ACTIONS.REMOVE_ISSUE] = () => {
    let listOfIssues = state.addedIssues ? state.addedIssues : [];
    let issueToRemove = action.payload.issue;

    return {
      ...state,
      addedIssues: _.filter(listOfIssues, (issue) => issueToRemove.referenceId !== issue.id)
    };
  };

  return actionsMap;
};

export const applyCommonReducers = (state, action) => {
  let reducerFunc = commonReducers(state, action)[action.type];

  return reducerFunc ? reducerFunc() : state;
};
