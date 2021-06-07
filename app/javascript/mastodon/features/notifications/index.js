import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import Column from '../../components/column';
import ColumnHeader from '../../components/column_header';
import {
  expandNotifications,
  scrollTopNotifications,
  loadPending,
  mountNotifications,
  unmountNotifications,
  markNotificationsAsRead,
} from '../../actions/notifications';
import { submitMarkers } from '../../actions/markers';
import { addColumn, removeColumn, moveColumn } from '../../actions/columns';
import NotificationContainer from './containers/notification_container';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import ColumnSettingsContainer from './containers/column_settings_container';
import FilterBarContainer from './containers/filter_bar_container';
import { createSelector } from 'reselect';
import { List as ImmutableList } from 'immutable';
import { debounce } from 'lodash';
import ScrollableList from '../../components/scrollable_list';
import LoadGap from '../../components/load_gap';
import Icon from 'mastodon/components/icon';
import compareId from 'mastodon/compare_id';
import NotificationsPermissionBanner from './components/notifications_permission_banner';

const messages = defineMessages({
  title: { id: 'column.notifications', defaultMessage: 'Notifications' },
  markAsRead : { id: 'notifications.mark_as_read', defaultMessage: 'Mark every notification as read' },
});

const getExcludedTypes = createSelector([
  state => state.getIn(['settings', 'notifications', 'shows']),
], (shows) => {
  return ImmutableList(shows.filter(item => !item).keys());
});

const getNotifications = createSelector([
  state => state.getIn(['settings', 'notifications', 'quickFilter', 'show']),
  state => state.getIn(['settings', 'notifications', 'quickFilter', 'active']),
  getExcludedTypes,
  state => state.getIn(['notifications', 'items']),
], (showFilterBar, allowedType, excludedTypes, notifications) => {
  if (!showFilterBar || allowedType === 'all') {
    // used if user changed the notification settings after loading the notifications from the server
    // otherwise a list of notifications will come pre-filtered from the backend
    // we need to turn it off for FilterBar in order not to block ourselves from seeing a specific category
    return notifications.filterNot(item => item !== null && excludedTypes.includes(item.get('type')));
  }
  return notifications.filter(item => item === null || allowedType === item.get('type'));
});

const mapStateToProps = state => ({
  showFilterBar: state.getIn(['settings', 'notifications', 'quickFilter', 'show']),
  notifications: getNotifications(state),
  isLoading: state.getIn(['notifications', 'isLoading'], true),
  isUnread: state.getIn(['notifications', 'unread']) > 0 || state.getIn(['notifications', 'pendingItems']).size > 0,
  hasMore: state.getIn(['notifications', 'hasMore']),
  numPending: state.getIn(['notifications', 'pendingItems'], ImmutableList()).size,
  lastReadId: state.getIn(['settings', 'notifications', 'showUnread']) ? state.getIn(['notifications', 'readMarkerId']) : '0',
  canMarkAsRead: state.getIn(['settings', 'notifications', 'showUnread']) && state.getIn(['notifications', 'readMarkerId']) !== '0' && getNotifications(state).some(item => item !== null && compareId(item.get('id'), state.getIn(['notifications', 'readMarkerId'])) > 0),
  needsNotificationPermission: state.getIn(['settings', 'notifications', 'alerts']).includes(true) && state.getIn(['notifications', 'browserSupport']) && state.getIn(['notifications', 'browserPermission']) === 'default' && !state.getIn(['settings', 'notifications', 'dismissPermissionBanner']),
});

@connect(mapStateToProps)
@injectIntl
export default class Notifications extends React.PureComponent {

  static propTypes = {
    columnId: PropTypes.string,
    notifications: ImmutablePropTypes.list.isRequired,
    showFilterBar: PropTypes.bool.isRequired,
    dispatch: PropTypes.func.isRequired,
    shouldUpdateScroll: PropTypes.func,
    intl: PropTypes.object.isRequired,
    isLoading: PropTypes.bool,
    isUnread: PropTypes.bool,
    multiColumn: PropTypes.bool,
    hasMore: PropTypes.bool,
    numPending: PropTypes.number,
    lastReadId: PropTypes.string,
    canMarkAsRead: PropTypes.bool,
    needsNotificationPermission: PropTypes.bool,
  };

  static defaultProps = {
    trackScroll: true,
  };

  componentWillMount() {
    this.props.dispatch(mountNotifications());
  }

  componentWillUnmount () {
    this.handleLoadOlder.cancel();
    this.handleScrollToTop.cancel();
    this.handleScroll.cancel();
    this.props.dispatch(scrollTopNotifications(false));
    this.props.dispatch(unmountNotifications());
  }

  handleLoadGap = (maxId) => {
    this.props.dispatch(expandNotifications({ maxId }));
  };

  handleLoadOlder = debounce(() => {
    const last = this.props.notifications.last();
    this.props.dispatch(expandNotifications({ maxId: last && last.get('id') }));
  }, 300, { leading: true });

  handleLoadPending = () => {
    this.props.dispatch(loadPending());
  };

  handleScrollToTop = debounce(() => {
    this.props.dispatch(scrollTopNotifications(true));
  }, 100);

  handleScroll = debounce(() => {
    this.props.dispatch(scrollTopNotifications(false));
  }, 100);

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('NOTIFICATIONS', {}));
    }
  }

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  }

  handleHeaderClick = () => {
    this.column.scrollTop();
  }

  setColumnRef = c => {
    this.column = c;
  }

  handleMoveUp = id => {
    const elementIndex = this.props.notifications.findIndex(item => item !== null && item.get('id') === id) - 1;
    this._selectChild(elementIndex, true);
  }

  handleMoveDown = id => {
    const elementIndex = this.props.notifications.findIndex(item => item !== null && item.get('id') === id) + 1;
    this._selectChild(elementIndex, false);
  }

  _selectChild (index, align_top) {
    const container = this.column.node;
    const element = container.querySelector(`article:nth-of-type(${index + 1}) .focusable`);

    if (element) {
      if (align_top && container.scrollTop > element.offsetTop) {
        element.scrollIntoView(true);
      } else if (!align_top && container.scrollTop + container.clientHeight < element.offsetTop + element.offsetHeight) {
        element.scrollIntoView(false);
      }
      element.focus();
    }
  }

  handleMarkAsRead = () => {
    this.props.dispatch(markNotificationsAsRead());
    this.props.dispatch(submitMarkers({ immediate: true }));
  };

  render () {
    const { intl, notifications, shouldUpdateScroll, isLoading, isUnread, columnId, multiColumn, hasMore, numPending, showFilterBar, lastReadId, canMarkAsRead, needsNotificationPermission } = this.props;
    const pinned = !!columnId;
    const emptyMessage = <FormattedMessage id='empty_column.notifications' defaultMessage="You don't have any notifications yet. When other people interact with you, you will see it here." />;

    let scrollableContent = null;

    const filterBarContainer = showFilterBar
      ? (<FilterBarContainer />)
      : null;

    if (isLoading && this.scrollableContent) {
      scrollableContent = this.scrollableContent;
    } else if (notifications.size > 0 || hasMore) {
      scrollableContent = notifications.map((item, index) => item === null ? (
        <LoadGap
          key={'gap:' + notifications.getIn([index + 1, 'id'])}
          disabled={isLoading}
          maxId={index > 0 ? notifications.getIn([index - 1, 'id']) : null}
          onClick={this.handleLoadGap}
        />
      ) : (
        <NotificationContainer
          key={item.get('id')}
          notification={item}
          accountId={item.get('account')}
          onMoveUp={this.handleMoveUp}
          onMoveDown={this.handleMoveDown}
          unread={lastReadId !== '0' && compareId(item.get('id'), lastReadId) > 0}
        />
      ));
    } else {
      scrollableContent = null;
    }

    this.scrollableContent = scrollableContent;

    const scrollContainer = (
      <ScrollableList
        scrollKey={`notifications-${columnId}`}
        trackScroll={!pinned}
        isLoading={isLoading}
        showLoading={isLoading && notifications.size === 0}
        hasMore={hasMore}
        numPending={numPending}
        prepend={needsNotificationPermission && <NotificationsPermissionBanner />}
        alwaysPrepend
        emptyMessage={emptyMessage}
        onLoadMore={this.handleLoadOlder}
        onLoadPending={this.handleLoadPending}
        onScrollToTop={this.handleScrollToTop}
        onScroll={this.handleScroll}
        shouldUpdateScroll={shouldUpdateScroll}
        bindToDocument={!multiColumn}
      >
        {scrollableContent}
      </ScrollableList>
    );

    let extraButton = null;

    if (canMarkAsRead) {
      extraButton = (
        <button
          aria-label={intl.formatMessage(messages.markAsRead)}
          title={intl.formatMessage(messages.markAsRead)}
          onClick={this.handleMarkAsRead}
          className='column-header__button'
        >
          <Icon id='check' />
        </button>
      );
    }

    return (
      <Column bindToDocument={!multiColumn} ref={this.setColumnRef} label={intl.formatMessage(messages.title)}>
        <ColumnHeader
          icon='bell'
          active={isUnread}
          title={intl.formatMessage(messages.title)}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
          extraButton={extraButton}
        >
          <ColumnSettingsContainer />
        </ColumnHeader>
        {filterBarContainer}
        {scrollContainer}
      </Column>
    );
  }

}
