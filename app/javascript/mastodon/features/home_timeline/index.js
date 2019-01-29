import React from 'react';
import { connect } from 'react-redux';
import { expandHomeTimeline } from '../../actions/timelines';
import PropTypes from 'prop-types';
import StatusListContainer from '../ui/containers/status_list_container';
import Column from '../../components/column';
import ColumnHeader from '../../components/column_header';
import { addColumn, removeColumn, moveColumn } from '../../actions/columns';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import ColumnSettingsContainer from './containers/column_settings_container';
import { Link } from 'react-router-dom';
import { fetchAnnouncements, toggleShowAnnouncements } from 'mastodon/actions/announcements';
import AnnouncementsContainer from 'mastodon/features/getting_started/containers/announcements_container';
import classNames from 'classnames';
import IconWithBadge from 'mastodon/components/icon_with_badge';

const messages = defineMessages({
  title: { id: 'column.home', defaultMessage: 'Home' },
  show_announcements: { id: 'home.show_announcements', defaultMessage: 'Show announcements' },
  hide_announcements: { id: 'home.hide_announcements', defaultMessage: 'Hide announcements' },
});

const mapStateToProps = state => ({
  hasUnread: state.getIn(['timelines', 'home', 'unread']) > 0,
  isPartial: state.getIn(['timelines', 'home', 'isPartial']),
  hasAnnouncements: !state.getIn(['announcements', 'items']).isEmpty(),
  unreadAnnouncements: state.getIn(['announcements', 'items']).count(item => !item.get('read')),
  showAnnouncements: state.getIn(['announcements', 'show']),
});

@connect(mapStateToProps)
@injectIntl
export default class HomeTimeline extends React.PureComponent {

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    shouldUpdateScroll: PropTypes.func,
    intl: PropTypes.object.isRequired,
    hasUnread: PropTypes.bool,
    isPartial: PropTypes.bool,
    columnId: PropTypes.string,
    multiColumn: PropTypes.bool,
    hasAnnouncements: PropTypes.bool,
    unreadAnnouncements: PropTypes.number,
    showAnnouncements: PropTypes.bool,
  };

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('HOME', {}));
    }
  }

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  }

  handleHeaderClick = () => {
    this.column.scrollTop();
  }

  setRef = c => {
    this.column = c;
  }

  handleLoadMore = maxId => {
    this.props.dispatch(expandHomeTimeline({ maxId }));
  }

  componentDidMount () {
    setTimeout(() => this.props.dispatch(fetchAnnouncements()), 700);
    this._checkIfReloadNeeded(false, this.props.isPartial);
  }

  componentDidUpdate (prevProps) {
    this._checkIfReloadNeeded(prevProps.isPartial, this.props.isPartial);
  }

  componentWillUnmount () {
    this._stopPolling();
  }

  _checkIfReloadNeeded (wasPartial, isPartial) {
    const { dispatch } = this.props;

    if (wasPartial === isPartial) {
      return;
    } else if (!wasPartial && isPartial) {
      this.polling = setInterval(() => {
        dispatch(expandHomeTimeline());
      }, 3000);
    } else if (wasPartial && !isPartial) {
      this._stopPolling();
    }
  }

  _stopPolling () {
    if (this.polling) {
      clearInterval(this.polling);
      this.polling = null;
    }
  }

  handleToggleAnnouncementsClick = (e) => {
    e.stopPropagation();
    this.props.dispatch(toggleShowAnnouncements());
  }

  render () {
    const { intl, shouldUpdateScroll, hasUnread, columnId, multiColumn, hasAnnouncements, unreadAnnouncements, showAnnouncements } = this.props;
    const pinned = !!columnId;

    let announcementsButton = null;

    if (hasAnnouncements) {
      announcementsButton = (
        <button
          className={classNames('column-header__button', { 'active': showAnnouncements })}
          title={intl.formatMessage(showAnnouncements ? messages.hide_announcements : messages.show_announcements)}
          aria-label={intl.formatMessage(showAnnouncements ? messages.hide_announcements : messages.show_announcements)}
          aria-pressed={showAnnouncements ? 'true' : 'false'}
          onClick={this.handleToggleAnnouncementsClick}
        >
          <IconWithBadge id='bullhorn' count={unreadAnnouncements} />
        </button>
      );
    }

    return (
      <Column bindToDocument={!multiColumn} ref={this.setRef} label={intl.formatMessage(messages.title)}>
        <ColumnHeader
          icon='home'
          active={hasUnread}
          title={intl.formatMessage(messages.title)}
          onPin={this.handlePin}
          onMove={this.handleMove}
          onClick={this.handleHeaderClick}
          pinned={pinned}
          multiColumn={multiColumn}
          extraButton={announcementsButton}
          appendContent={hasAnnouncements && showAnnouncements && <AnnouncementsContainer />}
        >
          <ColumnSettingsContainer />
        </ColumnHeader>

        <StatusListContainer
          trackScroll={!pinned}
          scrollKey={`home_timeline-${columnId}`}
          onLoadMore={this.handleLoadMore}
          timelineId='home'
          emptyMessage={<FormattedMessage id='empty_column.home' defaultMessage='Your home timeline is empty! Follow more people to fill it up. {suggestions}' values={{ suggestions: <Link to='/start'><FormattedMessage id='empty_column.home.suggestions' defaultMessage='See some suggestions' /></Link> }} />}
          shouldUpdateScroll={shouldUpdateScroll}
          bindToDocument={!multiColumn}
        />
      </Column>
    );
  }

}
