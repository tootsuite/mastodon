import React from 'react';
import { connect } from 'react-redux';
import ImmutablePureComponent from 'react-immutable-pure-component';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import IconButton from 'mastodon/components/icon_button';
import classNames from 'classnames';
import { me, boostModal } from 'mastodon/initial_state';
import { defineMessages, injectIntl } from 'react-intl';
import { replyCompose } from 'mastodon/actions/compose';
import { reblog, favourite, unreblog, unfavourite } from 'mastodon/actions/interactions';
import { makeGetStatus } from 'mastodon/selectors';
import { initBoostModal } from 'mastodon/actions/boosts';
import { openModal } from 'mastodon/actions/modal';

const messages = defineMessages({
  reply: { id: 'status.reply', defaultMessage: 'Reply' },
  replyAll: { id: 'status.replyAll', defaultMessage: 'Reply to thread' },
  reblog: { id: 'status.reblog', defaultMessage: 'Boost' },
  reblog_private: { id: 'status.reblog_private', defaultMessage: 'Boost with original visibility' },
  cancel_reblog_private: { id: 'status.cancel_reblog_private', defaultMessage: 'Unboost' },
  cannot_reblog: { id: 'status.cannot_reblog', defaultMessage: 'This post cannot be boosted' },
  favourite: { id: 'status.favourite', defaultMessage: 'Favourite' },
  replyConfirm: { id: 'confirmations.reply.confirm', defaultMessage: 'Reply' },
  replyMessage: { id: 'confirmations.reply.message', defaultMessage: 'Replying now will overwrite the message you are currently composing. Are you sure you want to proceed?' },
  open: { id: 'status.open', defaultMessage: 'Expand this status' },
});

const makeMapStateToProps = () => {
  const getStatus = makeGetStatus();

  const mapStateToProps = (state, { statusId }) => ({
    status: getStatus(state, { id: statusId }),
    askReplyConfirmation: state.getIn(['compose', 'text']).trim().length !== 0,
  });

  return mapStateToProps;
};

export default @connect(makeMapStateToProps)
@injectIntl
class Footer extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    statusId: PropTypes.string.isRequired,
    status: ImmutablePropTypes.map.isRequired,
    intl: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    askReplyConfirmation: PropTypes.bool,
    withOpenButton: PropTypes.bool,
    onClose: PropTypes.func,
  };

  _performReply = () => {
    const { dispatch, status, onClose } = this.props;
    const { router } = this.context;

    if (onClose) {
      onClose();
    }

    dispatch(replyCompose(status, router.history));
  };

  handleReplyClick = () => {
    const { dispatch, askReplyConfirmation, intl } = this.props;

    if (askReplyConfirmation) {
      dispatch(openModal('CONFIRM', {
        message: intl.formatMessage(messages.replyMessage),
        confirm: intl.formatMessage(messages.replyConfirm),
        onConfirm: this._performReply,
      }));
    } else {
      this._performReply();
    }
  };

  handleFavouriteClick = () => {
    const { dispatch, status } = this.props;

    if (status.get('favourited')) {
      dispatch(unfavourite(status));
    } else {
      dispatch(favourite(status));
    }
  };

  _performReblog = (status, privacy) => {
    const { dispatch } = this.props;
    dispatch(reblog(status, privacy));
  }

  handleReblogClick = e => {
    const { dispatch, status } = this.props;

    if (status.get('reblogged')) {
      dispatch(unreblog(status));
    } else if ((e && e.shiftKey) || !boostModal) {
      this._performReblog(status);
    } else {
      dispatch(initBoostModal({ status, onReblog: this._performReblog }));
    }
  };

  handleOpenClick = e => {
    const { router } = this.context;

    if (e.button !== 0 || !router) {
      return;
    }

    const { status, onClose } = this.props;

    if (onClose) {
      onClose();
    }

    router.history.push(`/statuses/${status.get('id')}`);
  }

  render () {
    const { status, intl, withOpenButton } = this.props;

    const publicStatus  = ['public', 'unlisted'].includes(status.get('visibility'));
    const reblogPrivate = status.getIn(['account', 'id']) === me && status.get('visibility') === 'private';

    let replyIcon, replyTitle;

    if (status.get('in_reply_to_id', null) === null) {
      replyIcon = 'reply';
      replyTitle = intl.formatMessage(messages.reply);
    } else {
      replyIcon = 'reply-all';
      replyTitle = intl.formatMessage(messages.replyAll);
    }

    let reblogTitle = '';

    if (status.get('reblogged')) {
      reblogTitle = intl.formatMessage(messages.cancel_reblog_private);
    } else if (publicStatus) {
      reblogTitle = intl.formatMessage(messages.reblog);
    } else if (reblogPrivate) {
      reblogTitle = intl.formatMessage(messages.reblog_private);
    } else {
      reblogTitle = intl.formatMessage(messages.cannot_reblog);
    }

    return (
      <div className='picture-in-picture__footer'>
        <IconButton className='status__action-bar-button' title={replyTitle} icon={status.get('in_reply_to_account_id') === status.getIn(['account', 'id']) ? 'reply' : replyIcon} onClick={this.handleReplyClick} counter={status.get('replies_count')} obfuscateCount />
        <IconButton className={classNames('status__action-bar-button', { reblogPrivate })} disabled={!publicStatus && !reblogPrivate}  active={status.get('reblogged')} pressed={status.get('reblogged')} title={reblogTitle} icon='retweet' onClick={this.handleReblogClick} counter={status.get('reblogs_count')} />
        <IconButton className='status__action-bar-button star-icon' animate active={status.get('favourited')} pressed={status.get('favourited')} title={intl.formatMessage(messages.favourite)} icon='star' onClick={this.handleFavouriteClick} counter={status.get('favourites_count')} />
        {withOpenButton && <IconButton className='status__action-bar-button' title={intl.formatMessage(messages.open)} icon='external-link' onClick={this.handleOpenClick} />}
      </div>
    );
  }

}
