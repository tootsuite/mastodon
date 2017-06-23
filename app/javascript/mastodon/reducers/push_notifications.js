import { STORE_HYDRATE } from '../actions/store';
import { SET_BROWSER_SUPPORT, SET_SUBSCRIPTION, CLEAR_SUBSCRIPTION, ALERTS_CHANGE } from '../actions/push_notifications';
import Immutable from 'immutable';

const initialState = Immutable.Map({
  subscription: null,
  backend_subscription: null,
  alerts: new Immutable.Map({
    follow: false,
    favourite: false,
    reblog: false,
    mention: false,
  }),
  isSubscribed: false,
  browserSupport: false,
});

const getAlerts = (subscriptions, backendSubscription) => {
  return backendSubscription && backendSubscription.alerts ?
    new Immutable.Map(backendSubscription.alerts) :
    initialState.get('alerts');
};

export default function push_subscriptions(state = initialState, action) {
  switch(action.type) {
  case STORE_HYDRATE:
    return state
      .set('backend_subscription', action.state.get('push_subscription'));
  case SET_BROWSER_SUPPORT:
    return state.set('browserSupport', action.value);
  case SET_SUBSCRIPTION:
    return state
      .set('subscription', action.subscription)
      .set('alerts', getAlerts(action.subscription, state.get('backendSubscription')))
      .set('isSubscribed', true);
  case CLEAR_SUBSCRIPTION:
    return initialState;
  case ALERTS_CHANGE:
    return state.setIn(action.key, action.value);
  default:
    return state;
  }
};
