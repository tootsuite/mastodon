import React from 'react';
import ImmutablePureComponent from 'react-immutable-pure-component';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import { connect } from 'react-redux';
import { makeGetAccount } from 'mastodon/selectors';
import Avatar from 'mastodon/components/avatar';
import DisplayName from 'mastodon/components/display_name';
import Permalink from 'mastodon/components/permalink';
import RelativeTimestamp from 'mastodon/components/relative_timestamp';
import IconButton from 'mastodon/components/icon_button';
import { FormattedMessage, injectIntl, defineMessages } from 'react-intl';
import { autoPlayGif, me, unfollowModal } from 'mastodon/initial_state';
import ShortNumber from 'mastodon/components/short_number';
import {
  followAccount,
  unfollowAccount,
  blockAccount,
  unblockAccount,
  unmuteAccount,
} from 'mastodon/actions/accounts';
import { openModal } from 'mastodon/actions/modal';
import { initMuteModal } from 'mastodon/actions/mutes';

const messages = defineMessages({
  follow: { id: 'account.follow', defaultMessage: 'Follow' },
  unfollow: { id: 'account.unfollow', defaultMessage: 'Unfollow' },
  requested: { id: 'account.requested', defaultMessage: 'Awaiting approval' },
  unblock: { id: 'account.unblock', defaultMessage: 'Unblock @{name}' },
  unmute: { id: 'account.unmute', defaultMessage: 'Unmute @{name}' },
  unfollowConfirm: {
    id: 'confirmations.unfollow.confirm',
    defaultMessage: 'Unfollow',
  },
});

const makeMapStateToProps = () => {
  const getAccount = makeGetAccount();

  const mapStateToProps = (state, { id }) => ({
    account: getAccount(state, id),
  });

  return mapStateToProps;
};

const mapDispatchToProps = (dispatch, { intl }) => ({
  onFollow(account) {
    if (
      account.getIn(['relationship', 'following']) ||
      account.getIn(['relationship', 'requested'])
    ) {
      if (unfollowModal) {
        dispatch(
          openModal('CONFIRM', {
            message: (
              <FormattedMessage
                id='confirmations.unfollow.message'
                defaultMessage='Are you sure you want to unfollow {name}?'
                values={{ name: <strong>@{account.get('acct')}</strong> }}
              />
            ),
            confirm: intl.formatMessage(messages.unfollowConfirm),
            onConfirm: () => dispatch(unfollowAccount(account.get('id'))),
          }),
        );
      } else {
        dispatch(unfollowAccount(account.get('id')));
      }
    } else {
      dispatch(followAccount(account.get('id')));
    }
  },

  onBlock(account) {
    if (account.getIn(['relationship', 'blocking'])) {
      dispatch(unblockAccount(account.get('id')));
    } else {
      dispatch(blockAccount(account.get('id')));
    }
  },

  onMute(account) {
    if (account.getIn(['relationship', 'muting'])) {
      dispatch(unmuteAccount(account.get('id')));
    } else {
      dispatch(initMuteModal(account));
    }
  },
});

export default
@injectIntl
@connect(makeMapStateToProps, mapDispatchToProps)
class AccountCard extends ImmutablePureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map.isRequired,
    intl: PropTypes.object.isRequired,
    onFollow: PropTypes.func.isRequired,
    onBlock: PropTypes.func.isRequired,
    onMute: PropTypes.func.isRequired,
  };

  handleMouseEnter = ({ currentTarget }) => {
    if (autoPlayGif) {
      return;
    }

    const emojis = currentTarget.querySelectorAll('.custom-emoji');

    for (var i = 0; i < emojis.length; i++) {
      let emoji = emojis[i];
      emoji.src = emoji.getAttribute('data-original');
    }
  }

  handleMouseLeave = ({ currentTarget }) => {
    if (autoPlayGif) {
      return;
    }

    const emojis = currentTarget.querySelectorAll('.custom-emoji');

    for (var i = 0; i < emojis.length; i++) {
      let emoji = emojis[i];
      emoji.src = emoji.getAttribute('data-static');
    }
  }

  handleFollow = () => {
    this.props.onFollow(this.props.account);
  };

  handleBlock = () => {
    this.props.onBlock(this.props.account);
  };

  handleMute = () => {
    this.props.onMute(this.props.account);
  };

  render() {
    const { account, intl } = this.props;

    let buttons;

    if (
      account.get('id') !== me &&
      account.get('relationship', null) !== null
    ) {
      const following = account.getIn(['relationship', 'following']);
      const requested = account.getIn(['relationship', 'requested']);
      const blocking = account.getIn(['relationship', 'blocking']);
      const muting = account.getIn(['relationship', 'muting']);

      if (requested) {
        buttons = (
          <IconButton
            disabled
            icon='hourglass'
            title={intl.formatMessage(messages.requested)}
          />
        );
      } else if (blocking) {
        buttons = (
          <IconButton
            active
            icon='unlock'
            title={intl.formatMessage(messages.unblock, {
              name: account.get('username'),
            })}
            onClick={this.handleBlock}
          />
        );
      } else if (muting) {
        buttons = (
          <IconButton
            active
            icon='volume-up'
            title={intl.formatMessage(messages.unmute, {
              name: account.get('username'),
            })}
            onClick={this.handleMute}
          />
        );
      } else if (!account.get('moved') || following) {
        buttons = (
          <IconButton
            icon={following ? 'user-times' : 'user-plus'}
            title={intl.formatMessage(
              following ? messages.unfollow : messages.follow,
            )}
            onClick={this.handleFollow}
            active={following}
          />
        );
      }
    }

    return (
      <div className='directory__card'>
        <div className='directory__card__img'>
          <img
            src={
              autoPlayGif ? account.get('header') : account.get('header_static')
            }
            alt=''
          />
        </div>

        <div className='directory__card__bar'>
          <Permalink
            className='directory__card__bar__name'
            href={account.get('url')}
            to={`/@${account.get('acct')}`}
          >
            <Avatar account={account} size={48} />
            <DisplayName account={account} />
          </Permalink>

          <div className='directory__card__bar__relationship account__relationship'>
            {buttons}
          </div>
        </div>

        <div className='directory__card__extra' onMouseEnter={this.handleMouseEnter} onMouseLeave={this.handleMouseLeave}>
          <div
            className='account__header__content translate'
            dangerouslySetInnerHTML={{ __html: account.get('note_emojified') }}
          />
        </div>

        <div className='directory__card__extra'>
          <div className='accounts-table__count'>
            <ShortNumber value={account.get('statuses_count')} />
            <small>
              <FormattedMessage id='account.posts' defaultMessage='Toots' />
            </small>
          </div>
          <div className='accounts-table__count'>
            <ShortNumber value={account.get('followers_count')} />{' '}
            <small>
              <FormattedMessage
                id='account.followers'
                defaultMessage='Followers'
              />
            </small>
          </div>
          <div className='accounts-table__count'>
            {account.get('last_status_at') === null ? (
              <FormattedMessage
                id='account.never_active'
                defaultMessage='Never'
              />
            ) : (
              <RelativeTimestamp timestamp={account.get('last_status_at')} />
            )}{' '}
            <small>
              <FormattedMessage
                id='account.last_status'
                defaultMessage='Last active'
              />
            </small>
          </div>
        </div>
      </div>
    );
  }

}
