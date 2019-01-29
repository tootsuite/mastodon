import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import Toggle from 'react-toggle';
import Button from '../../../components/button';
import { closeModal } from '../../../actions/modal';
import { muteAccount } from '../../../actions/accounts';
import { toggleHideNotifications, changeMuteDuration } from '../../../actions/mutes';

const messages = defineMessages({
  minutes: { id: 'intervals.full.minutes', defaultMessage: '{number, plural, one {# minute} other {# minutes}}' },
  hours: { id: 'intervals.full.hours', defaultMessage: '{number, plural, one {# hour} other {# hours}}' },
  days: { id: 'intervals.full.days', defaultMessage: '{number, plural, one {# day} other {# days}}' },
  indefinite: { id: 'mute_modal.indefinite', defaultMessage: 'Indefinite' },
});

const mapStateToProps = state => {
  return {
    account: state.getIn(['mutes', 'new', 'account']),
    notifications: state.getIn(['mutes', 'new', 'notifications']),
    muteDuration: state.getIn(['mutes', 'new', 'duration']),
  };
};

const mapDispatchToProps = dispatch => {
  return {
    onConfirm(account, notifications, muteDuration) {
      dispatch(muteAccount(account.get('id'), notifications, muteDuration));
    },

    onClose() {
      dispatch(closeModal());
    },

    onToggleNotifications() {
      dispatch(toggleHideNotifications());
    },

    onChangeMuteDuration(e) {
      dispatch(changeMuteDuration(e.target.value));
    },
  };
};

@connect(mapStateToProps, mapDispatchToProps)
@injectIntl
export default class MuteModal extends React.PureComponent {

  static propTypes = {
    account: PropTypes.object.isRequired,
    notifications: PropTypes.bool.isRequired,
    onClose: PropTypes.func.isRequired,
    onConfirm: PropTypes.func.isRequired,
    onToggleNotifications: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
    muteDuration: PropTypes.number.isRequired,
    onChangeMuteDuration: PropTypes.func.isRequired,
  };

  componentDidMount() {
    this.button.focus();
  }

  handleClick = () => {
    this.props.onClose();
    this.props.onConfirm(this.props.account, this.props.notifications, this.props.muteDuration);
  }

  handleCancel = () => {
    this.props.onClose();
  }

  setRef = (c) => {
    this.button = c;
  }

  toggleNotifications = () => {
    this.props.onToggleNotifications();
  }

  changeMuteDuration = (e) => {
    this.props.onChangeMuteDuration(e);
  }

  render () {
    const { account, notifications, muteDuration, intl } = this.props;

    return (
      <div className='modal-root__modal mute-modal'>
        <div className='mute-modal__container'>
          <p>
            <FormattedMessage
              id='confirmations.mute.message'
              defaultMessage='Are you sure you want to mute {name}?'
              values={{ name: <strong>@{account.get('acct')}</strong> }}
            />
          </p>
          <p className='mute-modal__explanation'>
            <FormattedMessage
              id='confirmations.mute.explanation'
              defaultMessage='This will hide posts from them and posts mentioning them, but it will still allow them to see your posts and follow you.'
            />
          </p>
          <div className='setting-toggle'>
            <Toggle id='mute-modal__hide-notifications-checkbox' checked={notifications} onChange={this.toggleNotifications} />
            <label className='setting-toggle__label' htmlFor='mute-modal__hide-notifications-checkbox'>
              <FormattedMessage id='mute_modal.hide_notifications' defaultMessage='Hide notifications from this user?' />
            </label>
          </div>
          <div>
            <span><FormattedMessage id='mute_modal.duration' defaultMessage='Duration' />: </span>

            {/* eslint-disable-next-line jsx-a11y/no-onchange */}
            <select value={muteDuration} onChange={this.changeMuteDuration}>
              <option value={0}>{intl.formatMessage(messages.indefinite)}</option>
              <option value={300}>{intl.formatMessage(messages.minutes, { number: 5 })}</option>
              <option value={1800}>{intl.formatMessage(messages.minutes, { number: 30 })}</option>
              <option value={3600}>{intl.formatMessage(messages.hours, { number: 1 })}</option>
              <option value={21600}>{intl.formatMessage(messages.hours, { number: 6 })}</option>
              <option value={86400}>{intl.formatMessage(messages.days, { number: 1 })}</option>
              <option value={259200}>{intl.formatMessage(messages.days, { number: 3 })}</option>
              <option value={604800}>{intl.formatMessage(messages.days, { number: 7 })}</option>
            </select>
          </div>
        </div>

        <div className='mute-modal__action-bar'>
          <Button onClick={this.handleCancel} className='mute-modal__cancel-button'>
            <FormattedMessage id='confirmation_modal.cancel' defaultMessage='Cancel' />
          </Button>
          <Button onClick={this.handleClick} ref={this.setRef}>
            <FormattedMessage id='confirmations.mute.confirm' defaultMessage='Mute' />
          </Button>
        </div>
      </div>
    );
  }

}
