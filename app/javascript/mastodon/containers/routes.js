import UI from '../features/ui';
import { store } from './mastodon';
import { fetchBundleRequest, fetchBundleSuccess, fetchBundleFail } from '../actions/bundles';

const loadRoute = (cb) => module => {
  store.dispatch(fetchBundleSuccess());
  cb(null, module.default);
};

const failRoute = (cb) => error => {
  store.dispatch(fetchBundleFail(error));
  cb(error, null);
};

export default [
  {
    path: '/',
    component: UI,
    // <IndexRedirect to='/getting-started' />
    childRoutes: [
      {
        path: 'getting-started',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/getting_started" */ '../features/getting_started').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'timelines/home',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/home_timeline" */ '../features/home_timeline').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'timelines/public',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/public_timeline" */ '../features/public_timeline').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'timelines/public/local',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/community_timeline" */ '../features/community_timeline').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'timelines/tag/:id',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/hashtag_timeline" */ '../features/hashtag_timeline').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },

      {
        path: 'notifications',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/notifications" */ '../features/notifications').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'favourites',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/favourited_statuses" */ '../features/favourited_statuses').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },

      {
        path: 'statuses/new',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/compose" */ '../features/compose').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'statuses/:statusId',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/status" */ '../features/status').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'statuses/:statusId/reblogs',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/reblogs" */ '../features/reblogs').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'statuses/:statusId/favourites',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/favourites" */ '../features/favourites').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },

      {
        path: 'accounts/:accountId',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/account_timeline" */ '../features/account_timeline').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'accounts/:accountId/followers',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/followers" */ '../features/followers').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'accounts/:accountId/following',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/following" */ '../features/following').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'accounts/:accountId/media',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/account_gallery" */ '../features/account_gallery').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },

      {
        path: 'follow_requests',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/follow_requests" */ '../features/follow_requests').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'blocks',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/blocks" */ '../features/blocks').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'mutes',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/mutes" */ '../features/mutes').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
      {
        path: 'report',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/report" */ '../features/report').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },

      {
        path: '*',
        getComponent: (location, cb) => {
          store.dispatch(fetchBundleRequest());
          import(/* webpackChunkName: "features/generic_not_found" */ '../features/generic_not_found').then(loadRoute(cb)).catch(failRoute(cb));
        },
      },
    ],
  },
];
