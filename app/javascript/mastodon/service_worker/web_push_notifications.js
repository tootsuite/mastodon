import IntlMessageFormat from 'intl-messageformat';
import locales from './web_push_locales';
import { unescape } from 'lodash';

const MAX_NOTIFICATIONS = 5;
const GROUP_TAG = 'tag';

const notify = options =>
  self.registration.getNotifications().then(notifications => {
    if (notifications.length >= MAX_NOTIFICATIONS) { // Reached the maximum number of notifications, proceed with grouping
      const group = {
        title: formatMessage('notifications.group', options.data.preferred_locale, { count: notifications.length + 1 }),
        body: notifications.sort((n1, n2) => n1.timestamp < n2.timestamp).map(notification => notification.title).join('\n'),
        badge: '/badge.png',
        icon: '/android-chrome-192x192.png',
        tag: GROUP_TAG,
        data: {
          url: (new URL('/web/notifications', self.location)).href,
          count: notifications.length + 1,
          preferred_locale: options.data.preferred_locale,
        },
      };

      notifications.forEach(notification => notification.close());

      return self.registration.showNotification(group.title, group);
    } else if (notifications.length === 1 && notifications[0].tag === GROUP_TAG) { // Already grouped, proceed with appending the notification to the group
      const group = cloneNotification(notifications[0]);

      group.title = formatMessage('notifications.group', options.data.preferred_locale, { count: group.data.count + 1 });
      group.body  = `${options.title}\n${group.body}`;
      group.data  = { ...group.data, count: group.data.count + 1 };

      return self.registration.showNotification(group.title, group);
    }

    return self.registration.showNotification(options.title, options);
  });

const fetchFromApi = (path, method, accessToken) => {
  const url = (new URL(path, self.location)).href;

  return fetch(url, {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },

    method: method,
    credentials: 'include',
  }).then(res => {
    if (res.ok) {
      return res;
    } else {
      throw new Error(res.status);
    }
  }).then(res => res.json());
};

const cloneNotification = notification => {
  const clone = {};
  let k;

  // Object.assign() does not work with notifications
  for(k in notification) {
    clone[k] = notification[k];
  }

  return clone;
};

const formatMessage = (messageId, locale, values = {}) =>
  (new IntlMessageFormat(locales[locale][messageId], locale)).format(values);

const htmlToPlainText = html =>
  unescape(html.replace(/<br\s*\/?>/g, '\n').replace(/<\/p><p>/g, '\n\n').replace(/<[^>]*>/g, ''));

const handlePush = (event) => {
  const { access_token, notification_id, preferred_locale, title, body, icon } = event.data.json();

  // Placeholder until more information can be loaded
  event.waitUntil(
    fetchFromApi(`/api/v1/notifications/${notification_id}`, 'get', access_token).then(notification => {
      const options = {};

      options.title     = formatMessage(`notification.${notification.type}`, preferred_locale, { name: notification.account.display_name.length > 0 ? notification.account.display_name : notification.account.username });
      options.body      = notification.status && htmlToPlainText(notification.status.content);
      options.icon      = notification.account.avatar_static;
      options.timestamp = notification.created_at && new Date(notification.created_at);
      options.tag       = notification.id;
      options.badge     = '/badge.png';
      options.image     = notification.status && notification.status.media_attachments.length > 0 && notification.status.media_attachments[0].preview_url || undefined;
      options.data      = { access_token, preferred_locale, id: notification.status ? notification.status.id : notification.account.id, url: notification.status ? `/web/@${notification.account.acct}/${notification.status.id}` : `/web/@${notification.account.acct}` };

      if (notification.status && notification.status.spoiler_text || notification.status.sensitive) {
        options.data.hiddenBody  = htmlToPlainText(notification.status.content);
        options.data.hiddenImage = notification.status.media_attachments.length > 0 && notification.status.media_attachments[0].preview_url;

        if (notification.status.spoiler_text) {
          options.body    = notification.status.spoiler_text;
        }

        options.image   = undefined;
        options.actions = [actionExpand(preferred_locale)];
      } else if (notification.type === 'mention') {
        options.actions = [actionReblog(preferred_locale), actionFavourite(preferred_locale)];
      }

      return notify(options);
    }).catch(() => {
      return notify({
        title,
        body,
        icon,
        tag: notification_id,
        timestamp: new Date(),
        badge: '/badge.png',
        data: { access_token, preferred_locale, url: '/web/notifications' },
      });
    }),
  );
};

const actionExpand = preferred_locale => ({
  action: 'expand',
  icon: '/web-push-icon_expand.png',
  title: formatMessage('status.show_more', preferred_locale),
});

const actionReblog = preferred_locale => ({
  action: 'reblog',
  icon: '/web-push-icon_reblog.png',
  title: formatMessage('status.reblog', preferred_locale),
});

const actionFavourite = preferred_locale => ({
  action: 'favourite',
  icon: '/web-push-icon_favourite.png',
  title: formatMessage('status.favourite', preferred_locale),
});

const findBestClient = clients => {
  const focusedClient = clients.find(client => client.focused);
  const visibleClient = clients.find(client => client.visibilityState === 'visible');

  return focusedClient || visibleClient || clients[0];
};

const expandNotification = notification => {
  const newNotification = cloneNotification(notification);

  newNotification.body    = newNotification.data.hiddenBody;
  newNotification.image   = newNotification.data.hiddenImage;
  newNotification.actions = [actionReblog(notification.data.preferred_locale), actionFavourite(notification.data.preferred_locale)];

  return self.registration.showNotification(newNotification.title, newNotification);
};

const removeActionFromNotification = (notification, action) => {
  const newNotification = cloneNotification(notification);

  newNotification.actions = newNotification.actions.filter(item => item.action !== action);

  return self.registration.showNotification(newNotification.title, newNotification);
};

const openUrl = url =>
  self.clients.matchAll({ type: 'window' }).then(clientList => {
    if (clientList.length !== 0) {
      const webClients = clientList.filter(client => /\/web\//.test(client.url));

      if (webClients.length !== 0) {
        const client       = findBestClient(webClients);
        const { pathname } = new URL(url, self.location);

        if (pathname.startsWith('/web/')) {
          return client.focus().then(client => client.postMessage({
            type: 'navigate',
            path: pathname.slice('/web/'.length - 1),
          }));
        }
      } else if ('navigate' in clientList[0]) { // Chrome 42-48 does not support navigate
        const client = findBestClient(clientList);

        return client.navigate(url).then(client => client.focus());
      }
    }

    return self.clients.openWindow(url);
  });

const handleNotificationClick = (event) => {
  const reactToNotificationClick = new Promise((resolve, reject) => {
    if (event.action) {
      if (event.action === 'expand') {
        resolve(expandNotification(event.notification));
      } else if (event.action === 'reblog') {
        const { data } = event.notification;
        resolve(fetchFromApi(`/api/v1/statuses/${data.id}/reblog`, 'post', data.access_token).then(() => removeActionFromNotification(event.notification, 'reblog')));
      } else if (event.action === 'favourite') {
        const { data } = event.notification;
        resolve(fetchFromApi(`/api/v1/statuses/${data.id}/favourite`, 'post', data.access_token).then(() => removeActionFromNotification(event.notification, 'favourite')));
      } else {
        reject(`Unknown action: ${event.action}`);
      }
    } else {
      event.notification.close();
      resolve(openUrl(event.notification.data.url));
    }
  });

  event.waitUntil(reactToNotificationClick);
};

self.addEventListener('push', handlePush);
self.addEventListener('notificationclick', handleNotificationClick);
