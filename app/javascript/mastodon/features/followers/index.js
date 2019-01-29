import React from 'react';
import { connect } from 'react-redux';
import ImmutablePureComponent from 'react-immutable-pure-component';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { debounce } from 'lodash';
import LoadingIndicator from '../../components/loading_indicator';
import {
  fetchAccount,
  fetchFollowers,
  expandFollowers,
} from '../../actions/accounts';
import { FormattedMessage } from 'react-intl';
import AccountContainer from '../../containers/account_container';
import Column from '../ui/components/column';
import HeaderContainer from '../account_timeline/containers/header_container';
import ColumnBackButton from '../../components/column_back_button';
import ScrollableList from '../../components/scrollable_list';
import MissingIndicator from 'mastodon/components/missing_indicator';
import TimelineHint from 'mastodon/components/timeline_hint';

const mapStateToProps = (state, props) => ({
  remote: !!(state.getIn(['accounts', props.params.accountId, 'acct']) !== state.getIn(['accounts', props.params.accountId, 'username'])),
  remoteUrl: state.getIn(['accounts', props.params.accountId, 'url']),
  isAccount: !!state.getIn(['accounts', props.params.accountId]),
  accountIds: state.getIn(['user_lists', 'followers', props.params.accountId, 'items']),
  hasMore: !!state.getIn(['user_lists', 'followers', props.params.accountId, 'next']),
  isLoading: state.getIn(['user_lists', 'followers', props.params.accountId, 'isLoading'], true),
  blockedBy: state.getIn(['relationships', props.params.accountId, 'blocked_by'], false),
});

const RemoteHint = ({ url }) => (
  <TimelineHint url={url} resource={<FormattedMessage id='timeline_hint.resources.followers' defaultMessage='Followers' />} />
);

RemoteHint.propTypes = {
  url: PropTypes.string.isRequired,
};

@connect(mapStateToProps)
export default class Followers extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    shouldUpdateScroll: PropTypes.func,
    accountIds: ImmutablePropTypes.list,
    hasMore: PropTypes.bool,
    isLoading: PropTypes.bool,
    blockedBy: PropTypes.bool,
    isAccount: PropTypes.bool,
    remote: PropTypes.bool,
    remoteUrl: PropTypes.string,
    multiColumn: PropTypes.bool,
  };

  componentWillMount () {
    if (!this.props.accountIds) {
      this.props.dispatch(fetchAccount(this.props.params.accountId));
      this.props.dispatch(fetchFollowers(this.props.params.accountId));
    }
  }

  componentWillReceiveProps (nextProps) {
    if (nextProps.params.accountId !== this.props.params.accountId && nextProps.params.accountId) {
      this.props.dispatch(fetchAccount(nextProps.params.accountId));
      this.props.dispatch(fetchFollowers(nextProps.params.accountId));
    }
  }

  handleLoadMore = debounce(() => {
    this.props.dispatch(expandFollowers(this.props.params.accountId));
  }, 300, { leading: true });

  render () {
    const { shouldUpdateScroll, accountIds, hasMore, blockedBy, isAccount, multiColumn, isLoading, remote, remoteUrl } = this.props;

    if (!isAccount) {
      return (
        <Column>
          <MissingIndicator />
        </Column>
      );
    }

    if (!accountIds) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    let emptyMessage;

    if (blockedBy) {
      emptyMessage = <FormattedMessage id='empty_column.account_unavailable' defaultMessage='Profile unavailable' />;
    } else if (remote && accountIds.isEmpty()) {
      emptyMessage = <RemoteHint url={remoteUrl} />;
    } else {
      emptyMessage = <FormattedMessage id='account.followers.empty' defaultMessage='No one follows this user yet.' />;
    }

    const remoteMessage = remote ? <RemoteHint url={remoteUrl} /> : null;

    return (
      <Column>
        <ColumnBackButton multiColumn={multiColumn} />

        <ScrollableList
          scrollKey='followers'
          hasMore={hasMore}
          isLoading={isLoading}
          onLoadMore={this.handleLoadMore}
          shouldUpdateScroll={shouldUpdateScroll}
          prepend={<HeaderContainer accountId={this.props.params.accountId} hideTabs />}
          alwaysPrepend
          append={remoteMessage}
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        >
          {blockedBy ? [] : accountIds.map(id =>
            <AccountContainer key={id} id={id} withNote={false} />,
          )}
        </ScrollableList>
      </Column>
    );
  }

}
