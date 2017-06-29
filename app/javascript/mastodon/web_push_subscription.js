import axios from 'axios';
import { store } from './containers/mastodon';
import { setBrowserSupport, setSubscription, clearSubscription } from './actions/push_notifications';

// Taken from https://www.npmjs.com/package/web-push
const urlBase64ToUint8Array = (base64String) => {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding)
    .replace(/\-/g, '+')
    .replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
};

const getApplicationServerKey = () => document.querySelector('[name="applicationServerKey"]').getAttribute('content');

const getRegistration = () => navigator.serviceWorker.ready;

const getPushSubscription = (registration) =>
  registration.pushManager.getSubscription()
    .then(subscription => ({ registration, subscription }));

const subscribe = (registration) =>
  registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(getApplicationServerKey()),
  })
    .then(subscription => {
      console.log('Got new subscription:', subscription.endpoint);
      return subscription;
    });

const unsubscribe = ({ registration, subscription }) =>
  subscription ? subscription.unsubscribe().then(() => registration) : registration;

const sendSubscriptionToBackend = (subscription) =>
  axios.post('/api/web/push_subscriptions', {
    data: subscription,
  }).then(response => response.data);

// Last one checks for payload support: https://web-push-book.gauntface.com/chapter-06/01-non-standards-browsers/#no-payload
const supportsPushNotifications = ('serviceWorker' in navigator && 'PushManager' in window && 'getKey' in PushSubscription.prototype);

export function register () {
  store.dispatch(setBrowserSupport(supportsPushNotifications));

  if (supportsPushNotifications) {
    console.log('This browser supports web push notifications.');
    if (!getApplicationServerKey()) {
      // eslint-disable-next-line no-console
      console.error('The VAPID public key is not set. You will not be able to receive Web Push Notifications.');
      return;
    }

    getRegistration()
      .then(getPushSubscription)
      .then(({ registration, subscription }) => {
        if (subscription !== null) {
          console.log('Subscription exists, checking if valid...');
          // We have a subscription, check if it is still valid
          const currentServerKey = (new Uint8Array(subscription.options.applicationServerKey)).toString();
          const subscriptionServerKey = urlBase64ToUint8Array(getApplicationServerKey()).toString();
          const serverEndpoint = store.getState().getIn(['push_notifications', 'subscription', 'endpoint']);

          console.log('VAPID public key is unchanged:', subscriptionServerKey === currentServerKey);
          console.log('Backend has same endpoint:', subscription.endpoint === serverEndpoint);

          if (!serverEndpoint) {
            console.log('Hm, the subscriptions seems to have removed in the backend...');
          }

          // If the VAPID public key did not change and the endpoint corresponds
          // to the endpoint saved in the backend, the subscription is valid
          if (subscriptionServerKey === currentServerKey && subscription.endpoint === serverEndpoint) {
            return subscription;
          } else {
            if (subscription.endpoint !== serverEndpoint) {
              console.log('Backend endpoint:', serverEndpoint);
              console.log('Subscr. endpoint:', subscription.endpoint);
            }

            console.log('Unsubscribing and subscribing...');
            // Something went wrong, try to subscribe again
            return unsubscribe({ registration, subscription }).then(subscribe).then(sendSubscriptionToBackend);
          }
        }

        console.log('Not subscribed, subscribing...');

        // No subscription, try to subscribe
        return subscribe(registration).then(sendSubscriptionToBackend);
      })
      .then(subscription => {
        // If we got a PushSubscription (and not a subscription object from the backend)
        // it means that the backend subscription is valid (and was set during hydration)
        if (!(subscription instanceof PushSubscription)) {
          console.log('Got a new subscription from the backend, dispatching action to save it in the store.');
          store.dispatch(setSubscription(subscription));
        } else {
          console.log('Got a PushSubscription, which is already saved in the store.');
        }
      })
      .catch(error => {
        if (error.code === 20 && error.name === 'AbortError') {
          // eslint-disable-next-line no-console
          console.warn('Your browser supports Web Push Notifications, but does not seem to implement the VAPID protocol.');
        } else if (error.code === 5 && error.name === 'InvalidCharacterError') {
          // eslint-disable-next-line no-console
          console.error('The VAPID public key seems to be invalid:', getApplicationServerKey());
        } else {
          console.error('Something went wrong:', error);
        }

        // Clear alerts and hide UI settings
        console.log('Clearing subscription from the store...');
        store.dispatch(clearSubscription());

        try {
          console.log('Fetching subscription and unsubscribing...');
          getRegistration()
            .then(getPushSubscription)
            .then(unsubscribe);
        } catch (e) {
          console.error('Something went wrong yet again:', error);
        }
      });
  } else {
    // eslint-disable-next-line no-console
    console.warn('Your browser does not support Web Push Notifications.');
  }
}
