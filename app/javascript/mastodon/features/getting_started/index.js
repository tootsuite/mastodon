import React from 'react';
import Column from '../ui/components/column';
import ColumnLink from '../ui/components/column_link';
import ColumnSubheading from '../ui/components/column_subheading';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { me, profile_directory, showTrends } from '../../initial_state';
import { fetchFollowRequests } from 'mastodon/actions/accounts';
import { List as ImmutableList } from 'immutable';
import NavigationContainer from '../compose/containers/navigation_container';
import Icon from 'mastodon/components/icon';
import LinkFooter from 'mastodon/features/ui/components/link_footer';
import TrendsContainer from './containers/trends_container';

const messages = defineMessages({
  home_timeline: { id: 'tabs_bar.home', defaultMessage: 'Home' },
  notifications: { id: 'tabs_bar.notifications', defaultMessage: 'Notifications' },
  public_timeline: { id: 'navigation_bar.public_timeline', defaultMessage: 'Federated timeline' },
  settings_subheading: { id: 'column_subheading.settings', defaultMessage: 'Settings' },
  community_timeline: { id: 'navigation_bar.community_timeline', defaultMessage: 'Local timeline' },
  direct: { id: 'navigation_bar.direct', defaultMessage: 'Direct messages' },
  bookmarks: { id: 'navigation_bar.bookmarks', defaultMessage: 'Bookmarks' },
  preferences: { id: 'navigation_bar.preferences', defaultMessage: 'Preferences' },
  follow_requests: { id: 'navigation_bar.follow_requests', defaultMessage: 'Follow requests' },
  favourites: { id: 'navigation_bar.favourites', defaultMessage: 'Favourites' },
  blocks: { id: 'navigation_bar.blocks', defaultMessage: 'Blocked users' },
  domain_blocks: { id: 'navigation_bar.domain_blocks', defaultMessage: 'Hidden domains' },
  mutes: { id: 'navigation_bar.mutes', defaultMessage: 'Muted users' },
  pins: { id: 'navigation_bar.pins', defaultMessage: 'Pinned toots' },
  lists: { id: 'navigation_bar.lists', defaultMessage: 'Lists' },
  discover: { id: 'navigation_bar.discover', defaultMessage: 'Discover' },
  personal: { id: 'navigation_bar.personal', defaultMessage: 'Personal' },
  security: { id: 'navigation_bar.security', defaultMessage: 'Security' },
  menu: { id: 'getting_started.heading', defaultMessage: 'Getting started' },
  profile_directory: { id: 'getting_started.directory', defaultMessage: 'Profile directory' },
});

const mapStateToProps = state => ({
  myAccount: state.getIn(['accounts', me]),
  columns: state.getIn(['settings', 'columns']),
  unreadFollowRequests: state.getIn(['user_lists', 'follow_requests', 'items'], ImmutableList()).size,
});

const mapDispatchToProps = dispatch => ({
  fetchFollowRequests: () => dispatch(fetchFollowRequests()),
});

const badgeDisplay = (number, limit) => {
  if (number === 0) {
    return undefined;
  } else if (limit && number >= limit) {
    return `${limit}+`;
  } else {
    return number;
  }
};

const NAVIGATION_PANEL_BREAKPOINT = 600 + (285 * 2) + (10 * 2);

export default @connect(mapStateToProps, mapDispatchToProps)
@injectIntl
class GettingStarted extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object.isRequired,
  };

  static propTypes = {
    intl: PropTypes.object.isRequired,
    myAccount: ImmutablePropTypes.map.isRequired,
    columns: ImmutablePropTypes.list,
    multiColumn: PropTypes.bool,
    fetchFollowRequests: PropTypes.func.isRequired,
    unreadFollowRequests: PropTypes.number,
    unreadNotifications: PropTypes.number,
  };

  componentDidMount () {
    const { fetchFollowRequests, multiColumn } = this.props;

    if (!multiColumn && window.innerWidth >= NAVIGATION_PANEL_BREAKPOINT) {
      this.context.router.history.replace('/home');
      return;
    }

    fetchFollowRequests();
  }

  render () {
    const { intl, myAccount, columns, multiColumn, unreadFollowRequests } = this.props;

    const navItems = [];
    let height = (multiColumn) ? 0 : 60;

    if (multiColumn) {
      navItems.push(
        <ColumnSubheading key='header-discover' text={intl.formatMessage(messages.discover)} />,
        <ColumnLink key='community_timeline' icon='users' text={intl.formatMessage(messages.community_timeline)} to='/public/local' />,
        <ColumnLink key='public_timeline' icon='globe' text={intl.formatMessage(messages.public_timeline)} to='/public' />,
      );

      height += 34 + 48*2;

      if (profile_directory) {
        navItems.push(
          <ColumnLink key='directory' icon='address-book' text={intl.formatMessage(messages.profile_directory)} to='/directory' />,
        );

        height += 48;
      }

      navItems.push(
        <ColumnSubheading key='header-personal' text={intl.formatMessage(messages.personal)} />,
      );

      height += 34;
    } else if (profile_directory) {
      navItems.push(
        <ColumnLink key='directory' icon='address-book' text={intl.formatMessage(messages.profile_directory)} to='/directory' />,
      );

      height += 48;
    }

    if (multiColumn && !columns.find(item => item.get('id') === 'HOME')) {
      navItems.push(
        <ColumnLink key='home' icon='home' text={intl.formatMessage(messages.home_timeline)} to='/home' />,
      );
      height += 48;
    }

    navItems.push(
      <ColumnLink key='direct' icon='envelope' text={intl.formatMessage(messages.direct)} to='/conversations' />,
      <ColumnLink key='bookmark' icon='bookmark' text={intl.formatMessage(messages.bookmarks)} to='/bookmarks' />,
      <ColumnLink key='favourites' icon='star' text={intl.formatMessage(messages.favourites)} to='/favourites' />,
      <ColumnLink key='lists' icon='list-ul' text={intl.formatMessage(messages.lists)} to='/lists' />,
    );

    height += 48*4;

    if (myAccount.get('locked') || unreadFollowRequests > 0) {
      navItems.push(<ColumnLink key='follow_requests' icon='user-plus' text={intl.formatMessage(messages.follow_requests)} badge={badgeDisplay(unreadFollowRequests, 40)} to='/follow_requests' />);
      height += 48;
    }

    if (!multiColumn) {
      navItems.push(
        <ColumnSubheading key='header-settings' text={intl.formatMessage(messages.settings_subheading)} />,
        <ColumnLink key='preferences' icon='gears' text={intl.formatMessage(messages.preferences)} href='/settings/preferences' />,
      );

      height += 34 + 48;
    }

    return (
      <Column bindToDocument={!multiColumn} label={intl.formatMessage(messages.menu)}>
        {multiColumn && <div className='column-header__wrapper'>
          <h1 className='column-header'>
            <button>
              <Icon id='bars' className='column-header__icon' fixedWidth />
              <FormattedMessage id='getting_started.heading' defaultMessage='Getting started' />
            </button>
          </h1>
        </div>}

        <div className='getting-started'>
          <div className='getting-started__wrapper' style={{ height }}>
            {!multiColumn && <NavigationContainer />}
            {navItems}
          </div>

          {!multiColumn && <div className='flex-spacer' />}

          <LinkFooter withHotkeys={multiColumn} />
        </div>

        {multiColumn && showTrends && <TrendsContainer />}
      </Column>
    );
  }

}
