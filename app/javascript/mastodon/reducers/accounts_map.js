import { ACCOUNT_IMPORT, ACCOUNTS_IMPORT } from '../actions/importer';
import { Map as ImmutableMap } from 'immutable';

const initialState = ImmutableMap();

export default function accountsMap(state = initialState, action) {
  switch(action.type) {
  case ACCOUNT_IMPORT:
    return state.set(action.account.acct, action.account.id);
  case ACCOUNTS_IMPORT:
    return state.withMutations(map => action.accounts.forEach(account => map.set(account.acct, account.id)));
  default:
    return state;
  }
};
