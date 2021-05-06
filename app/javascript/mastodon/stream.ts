import WebSocketClient from '@gamestdio/websocket';
import { Dispatch, Store } from 'redux';

let sharedConnection: WebSocket | EventSource | undefined;

type SubscriptionParams = {
  [key: string]: string
}
type Subscription = {
  channelName: string;
  params: SubscriptionParams;
  onConnect: ()=>void;
  onReceive: (event: StreamEvent) => void;
  onDisconnect: ()=>void;
}

type StreamEventType = typeof KNOWN_EVENT_TYPES
type StreamEvent = {
  event: StreamEventType
  payload: any
}

const subscriptions: Subscription[] = [];

type subscriptionCounters = {
  [key: string]: number
};
const subscriptionCounters: subscriptionCounters = {};

const addSubscription = (subscription: Subscription) => {
  subscriptions.push(subscription);
};

const removeSubscription = (subscription: Subscription) => {
  const index = subscriptions.indexOf(subscription);

  if (index !== -1) {
    subscriptions.splice(index, 1);
  }
};

type subscribe = (subscribe: Subscription) => void
const subscribe: subscribe = ({ channelName, params, onConnect }) => {
  const key = channelNameWithInlineParams(channelName, params);

  subscriptionCounters[key] = subscriptionCounters[key] || 0;

  if (subscriptionCounters[key] === 0) {
    // @ts-expect-error
    sharedConnection!.send(JSON.stringify({ type: 'subscribe', stream: channelName, ...params }));
  }

  subscriptionCounters[key] += 1;
  onConnect();
};

const unsubscribe = ({ channelName, params, onDisconnect }: Subscription) => {
  const key = channelNameWithInlineParams(channelName, params);

  subscriptionCounters[key] = subscriptionCounters[key] || 1;

  if (subscriptionCounters[key] === 1 && sharedConnection!.readyState === WebSocketClient.OPEN) {
    // @ts-expect-error
    sharedConnection!.send(JSON.stringify({ type: 'unsubscribe', stream: channelName, ...params }));
  }

  subscriptionCounters[key] -= 1;
  onDisconnect();
};

const sharedCallbacks = {
  connected() {
    subscriptions.forEach(subscription => subscribe(subscription));
  },

  received(data: StreamEvent['payload']) {
    const { stream } = data;

    subscriptions.filter(({ channelName, params }) => {
      const streamChannelName = stream[0];

      if (stream.length === 1) {
        return channelName === streamChannelName;
      }

      const streamIdentifier = stream[1];

      if (['hashtag', 'hashtag:local'].includes(channelName)) {
        return channelName === streamChannelName && params.tag === streamIdentifier;
      } else if (channelName === 'list') {
        return channelName === streamChannelName && params.list === streamIdentifier;
      }

      return false;
    }).forEach(subscription => {
      subscription.onReceive(data);
    });
  },

  disconnected() {
    subscriptions.forEach(subscription => unsubscribe(subscription));
  },

  reconnected() {
  },
};

type channelNameWithInlineParamsParams = {
  [key: string]: string;
}
type channelNameWithInlineParams = (
  channelName: string,
  params: channelNameWithInlineParamsParams
)=> string
const channelNameWithInlineParams: channelNameWithInlineParams= (channelName, params) => {
  if (Object.keys(params).length === 0) {
    return channelName;
  }

  return `${channelName}&${Object.keys(params).map(key => `${key}=${params[key]}`).join('&')}`;
};

type connectStreamParams = {
  [key: string]: string;
}
type connectStreamCallbacks = (dispatch: Function, getState: Function) => {
  onConnect: Subscription['onConnect'];
  onReceive: Subscription['onReceive'];
  onDisconnect: Subscription['onDisconnect'];
}
type connectStream = (
  channelName: string,
  params: connectStreamParams,
  callbacks: connectStreamCallbacks
) => void;
export const connectStream: connectStream = (channelName, params, callbacks) => (dispatch: Dispatch, getState: Store['getState']) => {
  const streamingAPIBaseURL = getState().getIn(['meta', 'streaming_api_base_url']);
  const accessToken = getState().getIn(['meta', 'access_token']);
  const { onConnect, onReceive, onDisconnect } = callbacks(dispatch, getState);

  // If we cannot use a websockets connection, we must fall back
  // to using individual connections for each channel
  if (!streamingAPIBaseURL.startsWith('ws')) {
    const connection = createConnection(streamingAPIBaseURL, accessToken, channelNameWithInlineParams(channelName, params), {
      connected() {
        onConnect();
      },

      received(data: any) {
        onReceive(data);
      },

      disconnected() {
        onDisconnect();
      },

      reconnected() {
        onConnect();
      },
    });

    return () => {
      connection.close();
    };
  }

  const subscription = {
    channelName,
    params,
    onConnect,
    onReceive,
    onDisconnect,
  };

  addSubscription(subscription);

  // If a connection is open, we can execute the subscription right now. Otherwise,
  // because we have already registered it, it will be executed on connect

  if (!sharedConnection) {
    sharedConnection = (createConnection(streamingAPIBaseURL, accessToken, '', sharedCallbacks));
  } else if (sharedConnection.readyState === WebSocketClient.OPEN) {
    subscribe(subscription);
  }

  return () => {
    removeSubscription(subscription);
    unsubscribe(subscription);
  };
};

const KNOWN_EVENT_TYPES = [
  'update',
  'delete',
  'notification',
  'conversation',
  'filters_changed',
  'encrypted_message',
  'announcement',
  'announcement.delete',
  'announcement.reaction',
] as const;

type handleEventSourceMessage = (e: MessageEvent<StreamEvent>, received: any) => void
const handleEventSourceMessage: handleEventSourceMessage = (e, received) => {
  received({
    event: e.type,
    payload: e.data,
  });
};

type createConnectionCallbacks = {
  connected: WebSocketClient['onopen'] & EventSource['onopen'];
  received: (event: MessageEvent<StreamEvent>)=> void;
  disconnected: WebSocketClient['onerror'] & EventSource['onerror'];
  reconnected: WebSocketClient['onreconnect'];
}
type createConnection = (
  streamingAPIBaseURL: string,
  accessToken: string,
  channelName: string,
  callbacks: createConnectionCallbacks
) => WebSocket | EventSource
const createConnection: createConnection = (streamingAPIBaseURL, accessToken, channelName, { connected, received, disconnected, reconnected }) => {
  const params = channelName.split('&');

  channelName = params.shift() as string;

  if (streamingAPIBaseURL.startsWith('ws')) {
    const ws = new WebSocketClient(`${streamingAPIBaseURL}/api/v1/streaming/?${params.join('&')}`, [accessToken]);

    ws.onopen = connected;
    ws.onmessage = e => received(JSON.parse(e.data));
    ws.onclose = disconnected;
    ws.onreconnect = reconnected;

    return ws;
  }

  channelName = channelName.replace(/:/g, '/');

  if (channelName.endsWith(':media')) {
    channelName = channelName.replace('/media', '');
    params.push('only_media=true');
  }

  params.push(`access_token=${accessToken}`);

  const es = new EventSource(`${streamingAPIBaseURL}/api/v1/streaming/${channelName}?${params.join('&')}`);

  KNOWN_EVENT_TYPES.forEach(type => {
    es.addEventListener(type, e => handleEventSourceMessage(e as MessageEvent<StreamEvent>, received));
  });

  es.onopen = connected;
  es.onerror = disconnected;

  return es;
};
