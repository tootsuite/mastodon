import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import classNames from 'classnames';
import Motion from 'mastodon/features/ui/util/optional_motion';
import spring from 'react-motion/lib/spring';
import escapeTextContentForBrowser from 'escape-html';
import emojify from 'mastodon/features/emoji/emoji';
import RelativeTimestamp from './relative_timestamp';
import Icon from 'mastodon/components/icon';

const messages = defineMessages({
  closed: { id: 'poll.closed', defaultMessage: 'Closed' },
  voted: { id: 'poll.voted', defaultMessage: 'You voted for this answer', description: 'Tooltip of the "voted" checkmark in polls' },
});

const makeEmojiMap = record => record.get('emojis').reduce((obj, emoji) => {
  obj[`:${emoji.get('shortcode')}:`] = emoji.toJS();
  return obj;
}, {});

export default @injectIntl
class Poll extends ImmutablePureComponent {

  static propTypes = {
    poll: ImmutablePropTypes.map,
    intl: PropTypes.object.isRequired,
    disabled: PropTypes.bool,
    refresh: PropTypes.func,
    onVote: PropTypes.func,
  };

  state = {
    selected: {},
    expired: null,
  };

  static getDerivedStateFromProps (props, state) {
    const { poll } = props;
    const expires_at = poll.get('expires_at');
    const expired = poll.get('expired') || expires_at !== null && (new Date(expires_at)).getTime() < (new Date());
    return (expired === state.expired) ? null : { expired };
  }

  componentDidMount () {
    this._setupTimer();
  }

  componentDidUpdate () {
    this._setupTimer();
  }

  componentWillUnmount () {
    clearTimeout(this._timer);
  }

  _setupTimer () {
    const { poll } = this.props;
    clearTimeout(this._timer);
    if (!this.state.expired) {
      const delay = (new Date(poll.get('expires_at'))).getTime() - (new Date());
      this._timer = setTimeout(() => {
        this.setState({ expired: true });
      }, delay);
    }
  }

  _toggleOption = value => {
    if (this.props.poll.get('multiple')) {
      const tmp = { ...this.state.selected };
      if (tmp[value]) {
        delete tmp[value];
      } else {
        tmp[value] = true;
      }
      this.setState({ selected: tmp });
    } else {
      const tmp = {};
      tmp[value] = true;
      this.setState({ selected: tmp });
    }
  }

  handleOptionChange = ({ target: { value } }) => {
    this._toggleOption(value);
  };

  handleOptionKeyPress = (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      this._toggleOption(e.target.getAttribute('data-index'));
      e.stopPropagation();
      e.preventDefault();
    }
  }

  handleVote = () => {
    if (this.props.disabled) {
      return;
    }

    this.props.onVote(Object.keys(this.state.selected));
  };

  handleRefresh = () => {
    if (this.props.disabled) {
      return;
    }

    this.props.refresh();
  };

  renderOption (option, optionIndex, showResults) {
    const { poll, disabled, intl } = this.props;
    const pollVotesCount  = poll.get('voters_count') || poll.get('votes_count');
    const percent         = pollVotesCount === 0 ? 0 : (option.get('votes_count') / pollVotesCount) * 100;
    const leading         = poll.get('options').filterNot(other => other.get('title') === option.get('title')).every(other => option.get('votes_count') >= other.get('votes_count'));
    const active          = !!this.state.selected[`${optionIndex}`];
    const voted           = option.get('voted') || (poll.get('own_votes') && poll.get('own_votes').includes(optionIndex));

    let titleEmojified = option.get('title_emojified');
    if (!titleEmojified) {
      const emojiMap = makeEmojiMap(poll);
      titleEmojified = emojify(escapeTextContentForBrowser(option.get('title')), emojiMap);
    }

    return (
      <li key={option.get('title')}>
        <label className={classNames('poll__option', { selectable: !showResults })}>
          <input
            name='vote-options'
            type={poll.get('multiple') ? 'checkbox' : 'radio'}
            value={optionIndex}
            checked={active}
            onChange={this.handleOptionChange}
            disabled={disabled}
          />

          {!showResults && (
            <span
              className={classNames('poll__input', { checkbox: poll.get('multiple'), active })}
              tabIndex='0'
              role={poll.get('multiple') ? 'checkbox' : 'radio'}
              onKeyPress={this.handleOptionKeyPress}
              aria-checked={active}
              aria-label={option.get('title')}
              data-index={optionIndex}
            />
          )}
          {showResults && <span className='poll__number'>
            {Math.round(percent)}%
          </span>}

          <span
            className='poll__option__text translate'
            dangerouslySetInnerHTML={{ __html: titleEmojified }}
          />

          {!!voted && <span className='poll__voted'>
            <Icon id='check' className='poll__voted__mark' title={intl.formatMessage(messages.voted)} />
          </span>}
        </label>

        {showResults && (
          <Motion defaultStyle={{ width: 0 }} style={{ width: spring(percent, { stiffness: 180, damping: 12 }) }}>
            {({ width }) =>
              <span className={classNames('poll__chart', { leading })} style={{ width: `${width}%` }} />
            }
          </Motion>
        )}
      </li>
    );
  }

  render () {
    const { poll, intl } = this.props;
    const { expired } = this.state;

    if (!poll) {
      return null;
    }

    const timeRemaining = expired ? intl.formatMessage(messages.closed) : <RelativeTimestamp timestamp={poll.get('expires_at')} futureDate />;
    const showResults   = poll.get('voted') || expired;
    const disabled      = this.props.disabled || Object.entries(this.state.selected).every(item => !item);

    let votesCount = null;

    if (poll.get('voters_count') !== null && poll.get('voters_count') !== undefined) {
      votesCount = <FormattedMessage id='poll.total_people' defaultMessage='{count, plural, one {# person} other {# people}}' values={{ count: poll.get('voters_count') }} />;
    } else {
      votesCount = <FormattedMessage id='poll.total_votes' defaultMessage='{count, plural, one {# vote} other {# votes}}' values={{ count: poll.get('votes_count') }} />;
    }

    return (
      <div className='poll'>
        <ul>
          {poll.get('options').map((option, i) => this.renderOption(option, i, showResults))}
        </ul>

        <div className='poll__footer'>
          {!showResults && <button className='button button-secondary' disabled={disabled} onClick={this.handleVote}><FormattedMessage id='poll.vote' defaultMessage='Vote' /></button>}
          {showResults && !this.props.disabled && <span><button className='poll__link' onClick={this.handleRefresh}><FormattedMessage id='poll.refresh' defaultMessage='Refresh' /></button> · </span>}
          {votesCount}
          {poll.get('expires_at') && <span> · {timeRemaining}</span>}
        </div>
      </div>
    );
  }

}
