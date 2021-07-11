import api, { getLinks } from '../api';
import { importFetchedAccount, importFetchedAccounts } from './importer';

export const ACCOUNT_FETCH_REQUEST = 'ACCOUNT_FETCH_REQUEST';
export const ACCOUNT_FETCH_SUCCESS = 'ACCOUNT_FETCH_SUCCESS';
export const ACCOUNT_FETCH_FAIL    = 'ACCOUNT_FETCH_FAIL';

export const ACCOUNT_LOOKUP_REQUEST = 'ACCOUNT_LOOKUP_REQUEST';
export const ACCOUNT_LOOKUP_SUCCESS = 'ACCOUNT_LOOKUP_SUCCESS';
export const ACCOUNT_LOOKUP_FAIL    = 'ACCOUNT_LOOKUP_FAIL';

export const ACCOUNT_FOLLOW_REQUEST = 'ACCOUNT_FOLLOW_REQUEST';
export const ACCOUNT_FOLLOW_SUCCESS = 'ACCOUNT_FOLLOW_SUCCESS';
export const ACCOUNT_FOLLOW_FAIL    = 'ACCOUNT_FOLLOW_FAIL';

export const ACCOUNT_UNFOLLOW_REQUEST = 'ACCOUNT_UNFOLLOW_REQUEST';
export const ACCOUNT_UNFOLLOW_SUCCESS = 'ACCOUNT_UNFOLLOW_SUCCESS';
export const ACCOUNT_UNFOLLOW_FAIL    = 'ACCOUNT_UNFOLLOW_FAIL';

export const ACCOUNT_BLOCK_REQUEST = 'ACCOUNT_BLOCK_REQUEST';
export const ACCOUNT_BLOCK_SUCCESS = 'ACCOUNT_BLOCK_SUCCESS';
export const ACCOUNT_BLOCK_FAIL    = 'ACCOUNT_BLOCK_FAIL';

export const ACCOUNT_UNBLOCK_REQUEST = 'ACCOUNT_UNBLOCK_REQUEST';
export const ACCOUNT_UNBLOCK_SUCCESS = 'ACCOUNT_UNBLOCK_SUCCESS';
export const ACCOUNT_UNBLOCK_FAIL    = 'ACCOUNT_UNBLOCK_FAIL';

export const ACCOUNT_MUTE_REQUEST = 'ACCOUNT_MUTE_REQUEST';
export const ACCOUNT_MUTE_SUCCESS = 'ACCOUNT_MUTE_SUCCESS';
export const ACCOUNT_MUTE_FAIL    = 'ACCOUNT_MUTE_FAIL';

export const ACCOUNT_UNMUTE_REQUEST = 'ACCOUNT_UNMUTE_REQUEST';
export const ACCOUNT_UNMUTE_SUCCESS = 'ACCOUNT_UNMUTE_SUCCESS';
export const ACCOUNT_UNMUTE_FAIL    = 'ACCOUNT_UNMUTE_FAIL';

export const ACCOUNT_PIN_REQUEST = 'ACCOUNT_PIN_REQUEST';
export const ACCOUNT_PIN_SUCCESS = 'ACCOUNT_PIN_SUCCESS';
export const ACCOUNT_PIN_FAIL    = 'ACCOUNT_PIN_FAIL';

export const ACCOUNT_UNPIN_REQUEST = 'ACCOUNT_UNPIN_REQUEST';
export const ACCOUNT_UNPIN_SUCCESS = 'ACCOUNT_UNPIN_SUCCESS';
export const ACCOUNT_UNPIN_FAIL    = 'ACCOUNT_UNPIN_FAIL';

export const FOLLOWERS_FETCH_REQUEST = 'FOLLOWERS_FETCH_REQUEST';
export const FOLLOWERS_FETCH_SUCCESS = 'FOLLOWERS_FETCH_SUCCESS';
export const FOLLOWERS_FETCH_FAIL    = 'FOLLOWERS_FETCH_FAIL';

export const FOLLOWERS_EXPAND_REQUEST = 'FOLLOWERS_EXPAND_REQUEST';
export const FOLLOWERS_EXPAND_SUCCESS = 'FOLLOWERS_EXPAND_SUCCESS';
export const FOLLOWERS_EXPAND_FAIL    = 'FOLLOWERS_EXPAND_FAIL';

export const FOLLOWING_FETCH_REQUEST = 'FOLLOWING_FETCH_REQUEST';
export const FOLLOWING_FETCH_SUCCESS = 'FOLLOWING_FETCH_SUCCESS';
export const FOLLOWING_FETCH_FAIL    = 'FOLLOWING_FETCH_FAIL';

export const FOLLOWING_EXPAND_REQUEST = 'FOLLOWING_EXPAND_REQUEST';
export const FOLLOWING_EXPAND_SUCCESS = 'FOLLOWING_EXPAND_SUCCESS';
export const FOLLOWING_EXPAND_FAIL    = 'FOLLOWING_EXPAND_FAIL';

export const RELATIONSHIPS_FETCH_REQUEST = 'RELATIONSHIPS_FETCH_REQUEST';
export const RELATIONSHIPS_FETCH_SUCCESS = 'RELATIONSHIPS_FETCH_SUCCESS';
export const RELATIONSHIPS_FETCH_FAIL    = 'RELATIONSHIPS_FETCH_FAIL';

export const FOLLOW_REQUESTS_FETCH_REQUEST = 'FOLLOW_REQUESTS_FETCH_REQUEST';
export const FOLLOW_REQUESTS_FETCH_SUCCESS = 'FOLLOW_REQUESTS_FETCH_SUCCESS';
export const FOLLOW_REQUESTS_FETCH_FAIL    = 'FOLLOW_REQUESTS_FETCH_FAIL';

export const FOLLOW_REQUESTS_EXPAND_REQUEST = 'FOLLOW_REQUESTS_EXPAND_REQUEST';
export const FOLLOW_REQUESTS_EXPAND_SUCCESS = 'FOLLOW_REQUESTS_EXPAND_SUCCESS';
export const FOLLOW_REQUESTS_EXPAND_FAIL    = 'FOLLOW_REQUESTS_EXPAND_FAIL';

export const FOLLOW_REQUEST_AUTHORIZE_REQUEST = 'FOLLOW_REQUEST_AUTHORIZE_REQUEST';
export const FOLLOW_REQUEST_AUTHORIZE_SUCCESS = 'FOLLOW_REQUEST_AUTHORIZE_SUCCESS';
export const FOLLOW_REQUEST_AUTHORIZE_FAIL    = 'FOLLOW_REQUEST_AUTHORIZE_FAIL';

export const FOLLOW_REQUEST_REJECT_REQUEST = 'FOLLOW_REQUEST_REJECT_REQUEST';
export const FOLLOW_REQUEST_REJECT_SUCCESS = 'FOLLOW_REQUEST_REJECT_SUCCESS';
export const FOLLOW_REQUEST_REJECT_FAIL    = 'FOLLOW_REQUEST_REJECT_FAIL';

export function fetchAccount(id) {
  return (dispatch, getState) => {
    dispatch(fetchRelationships([id]));
    dispatch(fetchAccountRequest(id));

    api(getState).get(`/api/v1/accounts/${id}`).then(response => {
      dispatch(importFetchedAccount(response.data));
      dispatch(fetchAccountSuccess());
    }).catch(error => {
      dispatch(fetchAccountFail(id, error));
    });
  };
};

export const lookupAccount = acct => (dispatch, getState) => {
  dispatch(lookupAccountRequest(acct));

  api(getState).get('/api/v1/accounts/lookup', { params: { acct } }).then(response => {
    dispatch(fetchRelationships([response.data.id]));
    dispatch(importFetchedAccount(response.data));
    dispatch(lookupAccountSuccess());
  }).catch(error => {
    dispatch(lookupAccountFail(acct, error));
  });
};

export const lookupAccountRequest = (acct) => ({
  type: ACCOUNT_LOOKUP_REQUEST,
  acct,
});

export const lookupAccountSuccess = () => ({
  type: ACCOUNT_LOOKUP_SUCCESS,
});

export const lookupAccountFail = (acct, error) => ({
  type: ACCOUNT_LOOKUP_FAIL,
  acct,
  error,
  skipAlert: true,
});

export function fetchAccountRequest(id) {
  return {
    type: ACCOUNT_FETCH_REQUEST,
    id,
  };
};

export function fetchAccountSuccess() {
  return {
    type: ACCOUNT_FETCH_SUCCESS,
  };
};

export function fetchAccountFail(id, error) {
  return {
    type: ACCOUNT_FETCH_FAIL,
    id,
    error,
    skipAlert: true,
  };
};

export function followAccount(id, options = { reblogs: true }) {
  return (dispatch, getState) => {
    const alreadyFollowing = getState().getIn(['relationships', id, 'following']);
    const locked = getState().getIn(['accounts', id, 'locked'], false);

    dispatch(followAccountRequest(id, locked));

    api(getState).post(`/api/v1/accounts/${id}/follow`, options).then(response => {
      dispatch(followAccountSuccess(response.data, alreadyFollowing));
    }).catch(error => {
      dispatch(followAccountFail(error, locked));
    });
  };
};

export function unfollowAccount(id) {
  return (dispatch, getState) => {
    dispatch(unfollowAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/unfollow`).then(response => {
      dispatch(unfollowAccountSuccess(response.data, getState().get('statuses')));
    }).catch(error => {
      dispatch(unfollowAccountFail(error));
    });
  };
};

export function followAccountRequest(id, locked) {
  return {
    type: ACCOUNT_FOLLOW_REQUEST,
    id,
    locked,
    skipLoading: true,
  };
};

export function followAccountSuccess(relationship, alreadyFollowing) {
  return {
    type: ACCOUNT_FOLLOW_SUCCESS,
    relationship,
    alreadyFollowing,
    skipLoading: true,
  };
};

export function followAccountFail(error, locked) {
  return {
    type: ACCOUNT_FOLLOW_FAIL,
    error,
    locked,
    skipLoading: true,
  };
};

export function unfollowAccountRequest(id) {
  return {
    type: ACCOUNT_UNFOLLOW_REQUEST,
    id,
    skipLoading: true,
  };
};

export function unfollowAccountSuccess(relationship, statuses) {
  return {
    type: ACCOUNT_UNFOLLOW_SUCCESS,
    relationship,
    statuses,
    skipLoading: true,
  };
};

export function unfollowAccountFail(error) {
  return {
    type: ACCOUNT_UNFOLLOW_FAIL,
    error,
    skipLoading: true,
  };
};

export function blockAccount(id) {
  return (dispatch, getState) => {
    dispatch(blockAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/block`).then(response => {
      // Pass in entire statuses map so we can use it to filter stuff in different parts of the reducers
      dispatch(blockAccountSuccess(response.data, getState().get('statuses')));
    }).catch(error => {
      dispatch(blockAccountFail(id, error));
    });
  };
};

export function unblockAccount(id) {
  return (dispatch, getState) => {
    dispatch(unblockAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/unblock`).then(response => {
      dispatch(unblockAccountSuccess(response.data));
    }).catch(error => {
      dispatch(unblockAccountFail(id, error));
    });
  };
};

export function blockAccountRequest(id) {
  return {
    type: ACCOUNT_BLOCK_REQUEST,
    id,
  };
};

export function blockAccountSuccess(relationship, statuses) {
  return {
    type: ACCOUNT_BLOCK_SUCCESS,
    relationship,
    statuses,
  };
};

export function blockAccountFail(error) {
  return {
    type: ACCOUNT_BLOCK_FAIL,
    error,
  };
};

export function unblockAccountRequest(id) {
  return {
    type: ACCOUNT_UNBLOCK_REQUEST,
    id,
  };
};

export function unblockAccountSuccess(relationship) {
  return {
    type: ACCOUNT_UNBLOCK_SUCCESS,
    relationship,
  };
};

export function unblockAccountFail(error) {
  return {
    type: ACCOUNT_UNBLOCK_FAIL,
    error,
  };
};


export function muteAccount(id, notifications, duration=0) {
  return (dispatch, getState) => {
    dispatch(muteAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/mute`, { notifications, duration }).then(response => {
      // Pass in entire statuses map so we can use it to filter stuff in different parts of the reducers
      dispatch(muteAccountSuccess(response.data, getState().get('statuses')));
    }).catch(error => {
      dispatch(muteAccountFail(id, error));
    });
  };
};

export function unmuteAccount(id) {
  return (dispatch, getState) => {
    dispatch(unmuteAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/unmute`).then(response => {
      dispatch(unmuteAccountSuccess(response.data));
    }).catch(error => {
      dispatch(unmuteAccountFail(id, error));
    });
  };
};

export function muteAccountRequest(id) {
  return {
    type: ACCOUNT_MUTE_REQUEST,
    id,
  };
};

export function muteAccountSuccess(relationship, statuses) {
  return {
    type: ACCOUNT_MUTE_SUCCESS,
    relationship,
    statuses,
  };
};

export function muteAccountFail(error) {
  return {
    type: ACCOUNT_MUTE_FAIL,
    error,
  };
};

export function unmuteAccountRequest(id) {
  return {
    type: ACCOUNT_UNMUTE_REQUEST,
    id,
  };
};

export function unmuteAccountSuccess(relationship) {
  return {
    type: ACCOUNT_UNMUTE_SUCCESS,
    relationship,
  };
};

export function unmuteAccountFail(error) {
  return {
    type: ACCOUNT_UNMUTE_FAIL,
    error,
  };
};


export function fetchFollowers(id) {
  return (dispatch, getState) => {
    dispatch(fetchFollowersRequest(id));

    api(getState).get(`/api/v1/accounts/${id}/followers`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(fetchFollowersSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(fetchFollowersFail(id, error));
    });
  };
};

export function fetchFollowersRequest(id) {
  return {
    type: FOLLOWERS_FETCH_REQUEST,
    id,
  };
};

export function fetchFollowersSuccess(id, accounts, next) {
  return {
    type: FOLLOWERS_FETCH_SUCCESS,
    id,
    accounts,
    next,
  };
};

export function fetchFollowersFail(id, error) {
  return {
    type: FOLLOWERS_FETCH_FAIL,
    id,
    error,
    skipNotFound: true,
  };
};

export function expandFollowers(id) {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'followers', id, 'next']);

    if (url === null) {
      return;
    }

    dispatch(expandFollowersRequest(id));

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(expandFollowersSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(expandFollowersFail(id, error));
    });
  };
};

export function expandFollowersRequest(id) {
  return {
    type: FOLLOWERS_EXPAND_REQUEST,
    id,
  };
};

export function expandFollowersSuccess(id, accounts, next) {
  return {
    type: FOLLOWERS_EXPAND_SUCCESS,
    id,
    accounts,
    next,
  };
};

export function expandFollowersFail(id, error) {
  return {
    type: FOLLOWERS_EXPAND_FAIL,
    id,
    error,
  };
};

export function fetchFollowing(id) {
  return (dispatch, getState) => {
    dispatch(fetchFollowingRequest(id));

    api(getState).get(`/api/v1/accounts/${id}/following`).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(fetchFollowingSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(fetchFollowingFail(id, error));
    });
  };
};

export function fetchFollowingRequest(id) {
  return {
    type: FOLLOWING_FETCH_REQUEST,
    id,
  };
};

export function fetchFollowingSuccess(id, accounts, next) {
  return {
    type: FOLLOWING_FETCH_SUCCESS,
    id,
    accounts,
    next,
  };
};

export function fetchFollowingFail(id, error) {
  return {
    type: FOLLOWING_FETCH_FAIL,
    id,
    error,
    skipNotFound: true,
  };
};

export function expandFollowing(id) {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'following', id, 'next']);

    if (url === null) {
      return;
    }

    dispatch(expandFollowingRequest(id));

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');

      dispatch(importFetchedAccounts(response.data));
      dispatch(expandFollowingSuccess(id, response.data, next ? next.uri : null));
      dispatch(fetchRelationships(response.data.map(item => item.id)));
    }).catch(error => {
      dispatch(expandFollowingFail(id, error));
    });
  };
};

export function expandFollowingRequest(id) {
  return {
    type: FOLLOWING_EXPAND_REQUEST,
    id,
  };
};

export function expandFollowingSuccess(id, accounts, next) {
  return {
    type: FOLLOWING_EXPAND_SUCCESS,
    id,
    accounts,
    next,
  };
};

export function expandFollowingFail(id, error) {
  return {
    type: FOLLOWING_EXPAND_FAIL,
    id,
    error,
  };
};

export function fetchRelationships(accountIds) {
  return (dispatch, getState) => {
    const loadedRelationships = getState().get('relationships');
    const newAccountIds = accountIds.filter(id => loadedRelationships.get(id, null) === null);

    if (newAccountIds.length === 0) {
      return;
    }

    dispatch(fetchRelationshipsRequest(newAccountIds));

    api(getState).get(`/api/v1/accounts/relationships?${newAccountIds.map(id => `id[]=${id}`).join('&')}`).then(response => {
      dispatch(fetchRelationshipsSuccess(response.data));
    }).catch(error => {
      dispatch(fetchRelationshipsFail(error));
    });
  };
};

export function fetchRelationshipsRequest(ids) {
  return {
    type: RELATIONSHIPS_FETCH_REQUEST,
    ids,
    skipLoading: true,
  };
};

export function fetchRelationshipsSuccess(relationships) {
  return {
    type: RELATIONSHIPS_FETCH_SUCCESS,
    relationships,
    skipLoading: true,
  };
};

export function fetchRelationshipsFail(error) {
  return {
    type: RELATIONSHIPS_FETCH_FAIL,
    error,
    skipLoading: true,
    skipNotFound: true,
  };
};

export function fetchFollowRequests() {
  return (dispatch, getState) => {
    dispatch(fetchFollowRequestsRequest());

    api(getState).get('/api/v1/follow_requests').then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedAccounts(response.data));
      dispatch(fetchFollowRequestsSuccess(response.data, next ? next.uri : null));
    }).catch(error => dispatch(fetchFollowRequestsFail(error)));
  };
};

export function fetchFollowRequestsRequest() {
  return {
    type: FOLLOW_REQUESTS_FETCH_REQUEST,
  };
};

export function fetchFollowRequestsSuccess(accounts, next) {
  return {
    type: FOLLOW_REQUESTS_FETCH_SUCCESS,
    accounts,
    next,
  };
};

export function fetchFollowRequestsFail(error) {
  return {
    type: FOLLOW_REQUESTS_FETCH_FAIL,
    error,
  };
};

export function expandFollowRequests() {
  return (dispatch, getState) => {
    const url = getState().getIn(['user_lists', 'follow_requests', 'next']);

    if (url === null) {
      return;
    }

    dispatch(expandFollowRequestsRequest());

    api(getState).get(url).then(response => {
      const next = getLinks(response).refs.find(link => link.rel === 'next');
      dispatch(importFetchedAccounts(response.data));
      dispatch(expandFollowRequestsSuccess(response.data, next ? next.uri : null));
    }).catch(error => dispatch(expandFollowRequestsFail(error)));
  };
};

export function expandFollowRequestsRequest() {
  return {
    type: FOLLOW_REQUESTS_EXPAND_REQUEST,
  };
};

export function expandFollowRequestsSuccess(accounts, next) {
  return {
    type: FOLLOW_REQUESTS_EXPAND_SUCCESS,
    accounts,
    next,
  };
};

export function expandFollowRequestsFail(error) {
  return {
    type: FOLLOW_REQUESTS_EXPAND_FAIL,
    error,
  };
};

export function authorizeFollowRequest(id) {
  return (dispatch, getState) => {
    dispatch(authorizeFollowRequestRequest(id));

    api(getState)
      .post(`/api/v1/follow_requests/${id}/authorize`)
      .then(() => dispatch(authorizeFollowRequestSuccess(id)))
      .catch(error => dispatch(authorizeFollowRequestFail(id, error)));
  };
};

export function authorizeFollowRequestRequest(id) {
  return {
    type: FOLLOW_REQUEST_AUTHORIZE_REQUEST,
    id,
  };
};

export function authorizeFollowRequestSuccess(id) {
  return {
    type: FOLLOW_REQUEST_AUTHORIZE_SUCCESS,
    id,
  };
};

export function authorizeFollowRequestFail(id, error) {
  return {
    type: FOLLOW_REQUEST_AUTHORIZE_FAIL,
    id,
    error,
  };
};


export function rejectFollowRequest(id) {
  return (dispatch, getState) => {
    dispatch(rejectFollowRequestRequest(id));

    api(getState)
      .post(`/api/v1/follow_requests/${id}/reject`)
      .then(() => dispatch(rejectFollowRequestSuccess(id)))
      .catch(error => dispatch(rejectFollowRequestFail(id, error)));
  };
};

export function rejectFollowRequestRequest(id) {
  return {
    type: FOLLOW_REQUEST_REJECT_REQUEST,
    id,
  };
};

export function rejectFollowRequestSuccess(id) {
  return {
    type: FOLLOW_REQUEST_REJECT_SUCCESS,
    id,
  };
};

export function rejectFollowRequestFail(id, error) {
  return {
    type: FOLLOW_REQUEST_REJECT_FAIL,
    id,
    error,
  };
};

export function pinAccount(id) {
  return (dispatch, getState) => {
    dispatch(pinAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/pin`).then(response => {
      dispatch(pinAccountSuccess(response.data));
    }).catch(error => {
      dispatch(pinAccountFail(error));
    });
  };
};

export function unpinAccount(id) {
  return (dispatch, getState) => {
    dispatch(unpinAccountRequest(id));

    api(getState).post(`/api/v1/accounts/${id}/unpin`).then(response => {
      dispatch(unpinAccountSuccess(response.data));
    }).catch(error => {
      dispatch(unpinAccountFail(error));
    });
  };
};

export function pinAccountRequest(id) {
  return {
    type: ACCOUNT_PIN_REQUEST,
    id,
  };
};

export function pinAccountSuccess(relationship) {
  return {
    type: ACCOUNT_PIN_SUCCESS,
    relationship,
  };
};

export function pinAccountFail(error) {
  return {
    type: ACCOUNT_PIN_FAIL,
    error,
  };
};

export function unpinAccountRequest(id) {
  return {
    type: ACCOUNT_UNPIN_REQUEST,
    id,
  };
};

export function unpinAccountSuccess(relationship) {
  return {
    type: ACCOUNT_UNPIN_SUCCESS,
    relationship,
  };
};

export function unpinAccountFail(error) {
  return {
    type: ACCOUNT_UNPIN_FAIL,
    error,
  };
};
