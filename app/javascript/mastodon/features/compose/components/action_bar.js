import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import DropdownMenuContainer from '../../../containers/dropdown_menu_container';
import { defineMessages, injectIntl } from 'react-intl';

const messages = defineMessages({
  edit_profile: { id: 'account.edit_profile', defaultMessage: 'Edit profile' },
  pins: { id: 'navigation_bar.pins', defaultMessage: 'Pinned toots' },
  preferences: { id: 'navigation_bar.preferences', defaultMessage: 'Preferences' },
  follow_requests: { id: 'navigation_bar.follow_requests', defaultMessage: 'Follow requests' },
  favourites: { id: 'navigation_bar.favourites', defaultMessage: 'Favourites' },
  lists: { id: 'navigation_bar.lists', defaultMessage: 'Lists' },
  blocks: { id: 'navigation_bar.blocks', defaultMessage: 'Blocked users' },
  domain_blocks: { id: 'navigation_bar.domain_blocks', defaultMessage: 'Hidden domains' },
  mutes: { id: 'navigation_bar.mutes', defaultMessage: 'Muted users' },
  filters: { id: 'navigation_bar.filters', defaultMessage: 'Muted words' },
  logout: { id: 'navigation_bar.logout', defaultMessage: 'Logout' },
  bookmarks: { id: 'navigation_bar.bookmarks', defaultMessage: 'Bookmarks' },
});

@injectIntl
export default class ActionBar extends React.PureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map.isRequired,
    onLogout: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleLogout = () => {
    this.props.onLogout();
  }

  render () {
    const { intl } = this.props;

    let menu = [];

    menu.push({ text: intl.formatMessage(messages.edit_profile), href: '/settings/profile' });
    menu.push({ text: intl.formatMessage(messages.preferences), href: '/settings/preferences' });
    menu.push({ text: intl.formatMessage(messages.pins), to: '/pinned' });
    menu.push(null);
    menu.push({ text: intl.formatMessage(messages.follow_requests), to: '/follow_requests' });
    menu.push({ text: intl.formatMessage(messages.favourites), to: '/favourites' });
    menu.push({ text: intl.formatMessage(messages.bookmarks), to: '/bookmarks' });
    menu.push({ text: intl.formatMessage(messages.lists), to: '/lists' });
    menu.push(null);
    menu.push({ text: intl.formatMessage(messages.mutes), to: '/mutes' });
    menu.push({ text: intl.formatMessage(messages.blocks), to: '/blocks' });
    menu.push({ text: intl.formatMessage(messages.domain_blocks), to: '/domain_blocks' });
    menu.push({ text: intl.formatMessage(messages.filters), href: '/filters' });
    menu.push(null);
    menu.push({ text: intl.formatMessage(messages.logout), action: this.handleLogout });

    return (
      <div className='compose__action-bar'>
        <div className='compose__action-bar-dropdown'>
          <DropdownMenuContainer items={menu} icon='chevron-down' size={16} direction='right' />
        </div>
      </div>
    );
  }

}
