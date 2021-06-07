import React from 'react';
import Column from '../ui/components/column';
import ColumnBackButtonSlim from '../../components/column_back_button_slim';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import PropTypes from 'prop-types';
import ImmutablePureComponent from 'react-immutable-pure-component';

const messages = defineMessages({
  heading: { id: 'keyboard_shortcuts.heading', defaultMessage: 'Keyboard Shortcuts' },
});

@injectIntl
export default class KeyboardShortcuts extends ImmutablePureComponent {

  static propTypes = {
    intl: PropTypes.object.isRequired,
    multiColumn: PropTypes.bool,
  };

  render () {
    const { intl, multiColumn } = this.props;

    return (
      <Column bindToDocument={!multiColumn} icon='question' heading={intl.formatMessage(messages.heading)}>
        <ColumnBackButtonSlim />
        <div className='keyboard-shortcuts scrollable optionally-scrollable'>
          <table>
            <thead>
              <tr>
                <th><FormattedMessage id='keyboard_shortcuts.hotkey' defaultMessage='Hotkey' /></th>
                <th><FormattedMessage id='keyboard_shortcuts.description' defaultMessage='Description' /></th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><kbd>r</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.reply' defaultMessage='to reply' /></td>
              </tr>
              <tr>
                <td><kbd>m</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.mention' defaultMessage='to mention author' /></td>
              </tr>
              <tr>
                <td><kbd>p</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.profile' defaultMessage="to open author's profile" /></td>
              </tr>
              <tr>
                <td><kbd>f</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.favourite' defaultMessage='to favourite' /></td>
              </tr>
              <tr>
                <td><kbd>b</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.boost' defaultMessage='to boost' /></td>
              </tr>
              <tr>
                <td><kbd>enter</kbd>, <kbd>o</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.enter' defaultMessage='to open status' /></td>
              </tr>
              <tr>
                <td><kbd>e</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.open_media' defaultMessage='to open media' /></td>
              </tr>
              <tr>
                <td><kbd>x</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.toggle_hidden' defaultMessage='to show/hide text behind CW' /></td>
              </tr>
              <tr>
                <td><kbd>h</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.toggle_sensitivity' defaultMessage='to show/hide media' /></td>
              </tr>
              <tr>
                <td><kbd>up</kbd>, <kbd>k</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.up' defaultMessage='to move up in the list' /></td>
              </tr>
              <tr>
                <td><kbd>down</kbd>, <kbd>j</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.down' defaultMessage='to move down in the list' /></td>
              </tr>
              <tr>
                <td><kbd>1</kbd>-<kbd>9</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.column' defaultMessage='to focus a status in one of the columns' /></td>
              </tr>
              <tr>
                <td><kbd>n</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.compose' defaultMessage='to focus the compose textarea' /></td>
              </tr>
              <tr>
                <td><kbd>alt</kbd>+<kbd>n</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.toot' defaultMessage='to start a brand new toot' /></td>
              </tr>
              <tr>
                <td><kbd>alt</kbd>+<kbd>x</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.spoilers' defaultMessage='to show/hide CW field' /></td>
              </tr>
              <tr>
                <td><kbd>backspace</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.back' defaultMessage='to navigate back' /></td>
              </tr>
              <tr>
                <td><kbd>s</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.search' defaultMessage='to focus search' /></td>
              </tr>
              <tr>
                <td><kbd>esc</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.unfocus' defaultMessage='to un-focus compose textarea/search' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>h</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.home' defaultMessage='to open home timeline' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>n</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.notifications' defaultMessage='to open notifications column' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>l</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.local' defaultMessage='to open local timeline' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>t</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.federated' defaultMessage='to open federated timeline' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>d</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.direct' defaultMessage='to open direct messages column' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>s</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.start' defaultMessage='to open "get started" column' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>f</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.favourites' defaultMessage='to open favourites list' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>p</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.pinned' defaultMessage='to open pinned toots list' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>u</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.my_profile' defaultMessage='to open your profile' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>b</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.blocked' defaultMessage='to open blocked users list' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>m</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.muted' defaultMessage='to open muted users list' /></td>
              </tr>
              <tr>
                <td><kbd>g</kbd>+<kbd>r</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.requests' defaultMessage='to open follow requests list' /></td>
              </tr>
              <tr>
                <td><kbd>?</kbd></td>
                <td><FormattedMessage id='keyboard_shortcuts.legend' defaultMessage='to display this legend' /></td>
              </tr>
            </tbody>
          </table>
        </div>
      </Column>
    );
  }

}
