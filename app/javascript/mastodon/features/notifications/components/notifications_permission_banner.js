import React from 'react';
import Icon from 'mastodon/components/icon';
import Button from 'mastodon/components/button';
import IconButton from 'mastodon/components/icon_button';
import { requestBrowserPermission } from 'mastodon/actions/notifications';
import { changeSetting } from 'mastodon/actions/settings';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
});

@connect()
@injectIntl
export default class NotificationsPermissionBanner extends React.PureComponent {

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleClick = () => {
    this.props.dispatch(requestBrowserPermission());
  }

  handleClose = () => {
    this.props.dispatch(changeSetting(['notifications', 'dismissPermissionBanner'], true));
  }

  render () {
    const { intl } = this.props;

    return (
      <div className='notifications-permission-banner'>
        <div className='notifications-permission-banner__close'>
          <IconButton icon='times' onClick={this.handleClose} title={intl.formatMessage(messages.close)} />
        </div>

        <h2><FormattedMessage id='notifications_permission_banner.title' defaultMessage='Never miss a thing' /></h2>
        <p><FormattedMessage id='notifications_permission_banner.how_to_control' defaultMessage="To receive notifications when Mastodon isn't open, enable desktop notifications. You can control precisely which types of interactions generate desktop notifications through the {icon} button above once they're enabled." values={{ icon: <Icon id='sliders' /> }} /></p>
        <Button onClick={this.handleClick}><FormattedMessage id='notifications_permission_banner.enable' defaultMessage='Enable desktop notifications' /></Button>
      </div>
    );
  }

}
