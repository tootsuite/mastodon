import React from 'react';
import { connect } from 'react-redux';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import { lookupAccount } from 'mastodon/actions/accounts';
import { expandAccountMediaTimeline } from '../../actions/timelines';
import LoadingIndicator from 'mastodon/components/loading_indicator';
import Column from '../ui/components/column';
import ColumnBackButton from 'mastodon/components/column_back_button';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { getAccountGallery } from 'mastodon/selectors';
import MediaItem from './components/media_item';
import HeaderContainer from '../account_timeline/containers/header_container';
import { ScrollContainer } from 'react-router-scroll-4';
import LoadMore from 'mastodon/components/load_more';
import MissingIndicator from 'mastodon/components/missing_indicator';
import { openModal } from 'mastodon/actions/modal';
import { FormattedMessage } from 'react-intl';

const mapStateToProps = (state, { params: { acct } }) => {
  const accountId = state.getIn(['accounts_map', acct]);

  if (!accountId) {
    return {
      isLoading: true,
    };
  }

  return {
    accountId,
    isAccount: !!state.getIn(['accounts', accountId]),
    attachments: getAccountGallery(state, accountId),
    isLoading: state.getIn(['timelines', `account:${accountId}:media`, 'isLoading']),
    hasMore: state.getIn(['timelines', `account:${accountId}:media`, 'hasMore']),
    suspended: state.getIn(['accounts', accountId, 'suspended'], false),
    blockedBy: state.getIn(['relationships', accountId, 'blocked_by'], false),
  };
};

class LoadMoreMedia extends ImmutablePureComponent {

  static propTypes = {
    shouldUpdateScroll: PropTypes.func,
    maxId: PropTypes.string,
    onLoadMore: PropTypes.func.isRequired,
  };

  handleLoadMore = () => {
    this.props.onLoadMore(this.props.maxId);
  }

  render () {
    return (
      <LoadMore
        disabled={this.props.disabled}
        onClick={this.handleLoadMore}
      />
    );
  }

}

export default @connect(mapStateToProps)
class AccountGallery extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.shape({
      acct: PropTypes.string.isRequired,
    }).isRequired,
    accountId: PropTypes.string,
    dispatch: PropTypes.func.isRequired,
    attachments: ImmutablePropTypes.list.isRequired,
    isLoading: PropTypes.bool,
    hasMore: PropTypes.bool,
    isAccount: PropTypes.bool,
    blockedBy: PropTypes.bool,
    suspended: PropTypes.bool,
    multiColumn: PropTypes.bool,
  };

  state = {
    width: 323,
  };

  _load () {
    const { accountId, dispatch } = this.props;

    dispatch(expandAccountMediaTimeline(accountId));
  }

  componentDidMount () {
    const { params: { acct }, accountId, dispatch } = this.props;

    if (accountId) {
      this._load();
    } else {
      dispatch(lookupAccount(acct));
    }
  }

  componentDidUpdate (prevProps) {
    const { params: { acct }, accountId, dispatch } = this.props;

    if (prevProps.accountId !== accountId && accountId) {
      this._load();
    } else if (prevProps.params.acct !== acct) {
      dispatch(lookupAccount(acct));
    }
  }

  handleScrollToBottom = () => {
    if (this.props.hasMore) {
      this.handleLoadMore(this.props.attachments.size > 0 ? this.props.attachments.last().getIn(['status', 'id']) : undefined);
    }
  }

  handleScroll = e => {
    const { scrollTop, scrollHeight, clientHeight } = e.target;
    const offset = scrollHeight - scrollTop - clientHeight;

    if (150 > offset && !this.props.isLoading) {
      this.handleScrollToBottom();
    }
  }

  handleLoadMore = maxId => {
    this.props.dispatch(expandAccountMediaTimeline(this.props.accountId, { maxId }));
  };

  handleLoadOlder = e => {
    e.preventDefault();
    this.handleScrollToBottom();
  }

  handleOpenMedia = attachment => {
    const { dispatch } = this.props;
    const statusId = attachment.getIn(['status', 'id']);

    if (attachment.get('type') === 'video') {
      dispatch(openModal('VIDEO', { media: attachment, statusId, options: { autoPlay: true } }));
    } else if (attachment.get('type') === 'audio') {
      dispatch(openModal('AUDIO', { media: attachment, statusId, options: { autoPlay: true } }));
    } else {
      const media = attachment.getIn(['status', 'media_attachments']);
      const index = media.findIndex(x => x.get('id') === attachment.get('id'));

      dispatch(openModal('MEDIA', { media, index, statusId }));
    }
  }

  handleRef = c => {
    if (c) {
      this.setState({ width: c.offsetWidth });
    }
  }

  render () {
    const { attachments, shouldUpdateScroll, isLoading, hasMore, isAccount, multiColumn, blockedBy, suspended } = this.props;
    const { width } = this.state;

    if (!isAccount) {
      return (
        <Column>
          <MissingIndicator />
        </Column>
      );
    }

    if (!attachments && isLoading) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    let loadOlder = null;

    if (hasMore && !(isLoading && attachments.size === 0)) {
      loadOlder = <LoadMore visible={!isLoading} onClick={this.handleLoadOlder} />;
    }

    let emptyMessage;

    if (suspended) {
      emptyMessage = <FormattedMessage id='empty_column.account_suspended' defaultMessage='Account suspended' />;
    } else if (blockedBy) {
      emptyMessage = <FormattedMessage id='empty_column.account_unavailable' defaultMessage='Profile unavailable' />;
    }

    return (
      <Column>
        <ColumnBackButton multiColumn={multiColumn} />

        <ScrollContainer scrollKey='account_gallery' shouldUpdateScroll={shouldUpdateScroll}>
          <div className='scrollable scrollable--flex' onScroll={this.handleScroll}>
            <HeaderContainer accountId={this.props.accountId} />

            {(suspended || blockedBy) ? (
              <div className='empty-column-indicator'>
                {emptyMessage}
              </div>
            ) : (
              <div role='feed' className='account-gallery__container' ref={this.handleRef}>
                {attachments.map((attachment, index) => attachment === null ? (
                  <LoadMoreMedia key={'more:' + attachments.getIn(index + 1, 'id')} maxId={index > 0 ? attachments.getIn(index - 1, 'id') : null} onLoadMore={this.handleLoadMore} />
                ) : (
                  <MediaItem key={attachment.get('id')} attachment={attachment} displayWidth={width} onOpenMedia={this.handleOpenMedia} />
                ))}

                {loadOlder}
              </div>
            )}

            {isLoading && attachments.size === 0 && (
              <div className='scrollable__append'>
                <LoadingIndicator />
              </div>
            )}
          </div>
        </ScrollContainer>
      </Column>
    );
  }

}
