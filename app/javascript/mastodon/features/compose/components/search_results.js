import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { FormattedMessage, defineMessages, injectIntl } from 'react-intl';
import AccountContainer from '../../../containers/account_container';
import StatusContainer from '../../../containers/status_container';
import ImmutablePureComponent from 'react-immutable-pure-component';
import Hashtag from '../../../components/hashtag';
import Icon from 'mastodon/components/icon';
import { searchEnabled } from '../../../initial_state';
import LoadMore from 'mastodon/components/load_more';

const messages = defineMessages({
  dismissSuggestion: { id: 'suggestions.dismiss', defaultMessage: 'Dismiss suggestion' },
});

@injectIntl
export default class SearchResults extends ImmutablePureComponent {

  static propTypes = {
    results: ImmutablePropTypes.map.isRequired,
    suggestions: ImmutablePropTypes.list.isRequired,
    fetchSuggestions: PropTypes.func.isRequired,
    expandSearch: PropTypes.func.isRequired,
    dismissSuggestion: PropTypes.func.isRequired,
    searchTerm: PropTypes.string,
    intl: PropTypes.object.isRequired,
  };

  componentDidMount () {
    if (this.props.searchTerm === '') {
      this.props.fetchSuggestions();
    }
  }

  componentDidUpdate () {
    if (this.props.searchTerm === '') {
      this.props.fetchSuggestions();
    }
  }

  handleLoadMoreAccounts = () => this.props.expandSearch('accounts');

  handleLoadMoreStatuses = () => this.props.expandSearch('statuses');

  handleLoadMoreHashtags = () => this.props.expandSearch('hashtags');

  render () {
    const { intl, results, suggestions, dismissSuggestion, searchTerm } = this.props;

    if (searchTerm === '' && !suggestions.isEmpty()) {
      return (
        <div className='search-results'>
          <div className='trends'>
            <div className='trends__header'>
              <Icon id='user-plus' fixedWidth />
              <FormattedMessage id='suggestions.header' defaultMessage='You might be interested in…' />
            </div>

            {suggestions && suggestions.map(suggestion => (
              <AccountContainer
                key={suggestion.get('account')}
                id={suggestion.get('account')}
                actionIcon={suggestion.get('source') === 'past_interaction' ? 'times' : null}
                actionTitle={suggestion.get('source') === 'past_interaction' ? intl.formatMessage(messages.dismissSuggestion) : null}
                onActionClick={dismissSuggestion}
              />
            ))}
          </div>
        </div>
      );
    }

    let accounts, statuses, hashtags;
    let count = 0;

    if (results.get('accounts') && results.get('accounts').size > 0) {
      count   += results.get('accounts').size;
      accounts = (
        <div className='search-results__section'>
          <h5><Icon id='users' fixedWidth /><FormattedMessage id='search_results.accounts' defaultMessage='People' /></h5>

          {results.get('accounts').map(accountId => <AccountContainer key={accountId} id={accountId} />)}

          {results.get('accounts').size >= 5 && <LoadMore visible onClick={this.handleLoadMoreAccounts} />}
        </div>
      );
    }

    if (results.get('statuses') && results.get('statuses').size > 0) {
      count   += results.get('statuses').size;
      statuses = (
        <div className='search-results__section'>
          <h5><Icon id='quote-right' fixedWidth /><FormattedMessage id='search_results.statuses' defaultMessage='Toots' /></h5>

          {results.get('statuses').map(statusId => <StatusContainer key={statusId} id={statusId} />)}

          {results.get('statuses').size >= 5 && <LoadMore visible onClick={this.handleLoadMoreStatuses} />}
        </div>
      );
    } else if(results.get('statuses') && results.get('statuses').size === 0 && !searchEnabled && !(searchTerm.startsWith('@') || searchTerm.startsWith('#') || searchTerm.includes(' '))) {
      statuses = (
        <div className='search-results__section'>
          <h5><Icon id='quote-right' fixedWidth /><FormattedMessage id='search_results.statuses' defaultMessage='Toots' /></h5>

          <div className='search-results__info'>
            <FormattedMessage id='search_results.statuses_fts_disabled' defaultMessage='Searching toots by their content is not enabled on this Mastodon server.' />
          </div>
        </div>
      );
    }

    if (results.get('hashtags') && results.get('hashtags').size > 0) {
      count += results.get('hashtags').size;
      hashtags = (
        <div className='search-results__section'>
          <h5><Icon id='hashtag' fixedWidth /><FormattedMessage id='search_results.hashtags' defaultMessage='Hashtags' /></h5>

          {results.get('hashtags').map(hashtag => <Hashtag key={hashtag.get('name')} hashtag={hashtag} />)}

          {results.get('hashtags').size >= 5 && <LoadMore visible onClick={this.handleLoadMoreHashtags} />}
        </div>
      );
    }

    return (
      <div className='search-results'>
        <div className='search-results__header'>
          <Icon id='search' fixedWidth />
          <FormattedMessage id='search_results.total' defaultMessage='{count, number} {count, plural, one {result} other {results}}' values={{ count }} />
        </div>

        {accounts}
        {statuses}
        {hashtags}
      </div>
    );
  }

}
