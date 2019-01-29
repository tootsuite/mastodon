import React from 'react';
import { connect } from 'react-redux';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import ImmutablePureComponent from 'react-immutable-pure-component';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { debounce } from 'lodash';
import LoadingIndicator from '../../components/loading_indicator';
import Column from '../ui/components/column';
import ColumnBackButtonSlim from '../../components/column_back_button_slim';
import AccountContainer from '../../containers/account_container';
import { fetchMutes, expandMutes } from '../../actions/mutes';
import ScrollableList from '../../components/scrollable_list';

const messages = defineMessages({
  heading: { id: 'column.mutes', defaultMessage: 'Muted users' },
});

const mapStateToProps = state => ({
  accountIds: state.getIn(['user_lists', 'mutes', 'items']),
  hasMore: !!state.getIn(['user_lists', 'mutes', 'next']),
  isLoading: state.getIn(['user_lists', 'mutes', 'isLoading'], true),
});

@connect(mapStateToProps)
@injectIntl
export default class Mutes extends ImmutablePureComponent {

  static propTypes = {
    params: PropTypes.object.isRequired,
    dispatch: PropTypes.func.isRequired,
    shouldUpdateScroll: PropTypes.func,
    hasMore: PropTypes.bool,
    isLoading: PropTypes.bool,
    accountIds: ImmutablePropTypes.list,
    intl: PropTypes.object.isRequired,
    multiColumn: PropTypes.bool,
  };

  componentWillMount () {
    this.props.dispatch(fetchMutes());
  }

  handleLoadMore = debounce(() => {
    this.props.dispatch(expandMutes());
  }, 300, { leading: true });

  render () {
    const { intl, shouldUpdateScroll, hasMore, accountIds, multiColumn, isLoading } = this.props;

    if (!accountIds) {
      return (
        <Column>
          <LoadingIndicator />
        </Column>
      );
    }

    const emptyMessage = <FormattedMessage id='empty_column.mutes' defaultMessage="You haven't muted any users yet." />;

    return (
      <Column bindToDocument={!multiColumn} icon='volume-off' heading={intl.formatMessage(messages.heading)}>
        <ColumnBackButtonSlim />
        <ScrollableList
          scrollKey='mutes'
          onLoadMore={this.handleLoadMore}
          hasMore={hasMore}
          isLoading={isLoading}
          shouldUpdateScroll={shouldUpdateScroll}
          emptyMessage={emptyMessage}
          bindToDocument={!multiColumn}
        >
          {accountIds.map(id =>
            <AccountContainer key={id} id={id} />,
          )}
        </ScrollableList>
      </Column>
    );
  }

}
