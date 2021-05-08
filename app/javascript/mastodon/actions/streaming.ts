import { connectStream } from '../stream';
import {
  updateTimeline,
  deleteFromTimelines,
  expandHomeTimeline,
  connectTimeline,
  disconnectTimeline,
} from './timelines';
import { updateNotifications, expandNotifications } from './notifications';
import { updateConversations } from './conversations';
import {
  fetchAnnouncements,
  updateAnnouncements,
  updateReaction as updateAnnouncementsReaction,
  deleteAnnouncement,
} from './announcements';
import { fetchFilters } from './filters';
import { getLocale } from '../locales';

const { messages } = getLocale();

type randomUpTo = (max: number) => number
const randomUpTo: randomUpTo = (max) =>
  Math.floor(Math.random() * Math.floor(max));


type connectTimelineStreamParams = {
  [key: string]: string
}
type connectTimelineStreamOption = {
  fallback?: (dispatch: Function, done: () => void) => void;
  accept?: (object: object) => boolean;
}
type connectTimelineStream = (
  timelineId: string,
  channelName: string,
  params?: connectTimelineStreamParams,
  options?: connectTimelineStreamOption,
) => void

export const connectTimelineStream: connectTimelineStream = (timelineId, channelName, params = {}, options = {}) =>
  connectStream(channelName, params, (dispatch: Function, getState: Function) => {
    const locale = getState().getIn(['meta', 'locale']);

    let pollingId: number | null;

    /**
     * @param {function(Function, Function): void} fallback
     */
    const useFallback = (fallback: any) => {
      fallback(dispatch, () => {
        pollingId = window.setTimeout(() => useFallback(fallback), 20000 + randomUpTo(20000));
      });
    };

    return {
      onConnect() {
        dispatch(connectTimeline(timelineId));

        if (pollingId) {
          clearTimeout(pollingId);
          pollingId = null;
        }
      },

      onDisconnect() {
        dispatch(disconnectTimeline(timelineId));

        if (options.fallback) {
          pollingId = window.setTimeout(() => useFallback(options.fallback), randomUpTo(40000));
        }
      },

      onReceive (data: any) {
        switch(data.event) {
        case 'update':
          dispatch(updateTimeline(timelineId, JSON.parse(data.payload), options.accept));
          break;
        case 'delete':
          dispatch(deleteFromTimelines(data.payload));
          break;
        case 'notification':
          dispatch(updateNotifications(JSON.parse(data.payload), messages, locale));
          break;
        case 'conversation':
          dispatch(updateConversations(JSON.parse(data.payload)));
          break;
        case 'filters_changed':
          dispatch(fetchFilters());
          break;
        case 'announcement':
          dispatch(updateAnnouncements(JSON.parse(data.payload)));
          break;
        case 'announcement.reaction':
          dispatch(updateAnnouncementsReaction(JSON.parse(data.payload)));
          break;
        case 'announcement.delete':
          dispatch(deleteAnnouncement(data.payload));
          break;
        }
      },
    };
  });

type refreshHomeTimelineAndNotification = (dispatch: Function, done: () => void) => void
const refreshHomeTimelineAndNotification: refreshHomeTimelineAndNotification = (dispatch, done) => {
  dispatch(expandHomeTimeline({}, () =>
    dispatch(expandNotifications({}, () =>
      dispatch(fetchAnnouncements(done))))));
};

type connectUserStream = () => void
export const connectUserStream: connectUserStream = () =>
  connectTimelineStream('home', 'user', {}, { fallback: refreshHomeTimelineAndNotification });

type connectCommunityStreamOption = {
  onlyMedia?: boolean
}
export const connectCommunityStream = ({ onlyMedia }: connectCommunityStreamOption = {}) =>
  connectTimelineStream(`community${onlyMedia ? ':media' : ''}`, `public:local${onlyMedia ? ':media' : ''}`);

type connectPublicStreamOption = {
  onlyMedia?: boolean
  onlyRemote?: boolean
}
type connectPublicStream = (option: connectPublicStreamOption) => void
export const connectPublicStream: connectPublicStream = ({ onlyMedia, onlyRemote } = {}) =>
  connectTimelineStream(`public${onlyRemote ? ':remote' : ''}${onlyMedia ? ':media' : ''}`, `public${onlyRemote ? ':remote' : ''}${onlyMedia ? ':media' : ''}`);

type connectHashtagStream = (
  columnId: string,
  tagName: string,
  onlyLocal: boolean,
  accept: (object: object) => boolean,
) => void
export const connectHashtagStream: connectHashtagStream = (columnId, tagName, onlyLocal, accept) =>
  connectTimelineStream(`hashtag:${columnId}${onlyLocal ? ':local' : ''}`, `hashtag${onlyLocal ? ':local' : ''}`, { tag: tagName }, { accept });

type connectDirectStream = () => void
export const connectDirectStream: connectDirectStream = () =>
  connectTimelineStream('direct', 'direct');


type connectListStream = (listId: string) => void
export const connectListStream: connectListStream = listId =>
  connectTimelineStream(`list:${listId}`, 'list', { list: listId });
