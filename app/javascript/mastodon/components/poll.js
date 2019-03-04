import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import classNames from 'classnames';
import { vote, fetchPoll } from 'mastodon/actions/polls';
import Motion from 'mastodon/features/ui/util/optional_motion';
import spring from 'react-motion/lib/spring';

const messages = defineMessages({
  moments: { id: 'time_remaining.moments', defaultMessage: 'Moments remaining' },
  seconds: { id: 'time_remaining.seconds', defaultMessage: '{number, plural, one {# second} other {# seconds}} left' },
  minutes: { id: 'time_remaining.minutes', defaultMessage: '{number, plural, one {# minute} other {# minutes}} left' },
  hours: { id: 'time_remaining.hours', defaultMessage: '{number, plural, one {# hour} other {# hours}} left' },
  days: { id: 'time_remaining.days', defaultMessage: '{number, plural, one {# day} other {# days}} left' },
});

const SECOND = 1000;
const MINUTE = 1000 * 60;
const HOUR   = 1000 * 60 * 60;
const DAY    = 1000 * 60 * 60 * 24;

const timeRemainingString = (intl, date, now) => {
  const delta = date.getTime() - now;

  let relativeTime;

  if (delta < 10 * SECOND) {
    relativeTime = intl.formatMessage(messages.moments);
  } else if (delta < MINUTE) {
    relativeTime = intl.formatMessage(messages.seconds, { number: Math.floor(delta / SECOND) });
  } else if (delta < HOUR) {
    relativeTime = intl.formatMessage(messages.minutes, { number: Math.floor(delta / MINUTE) });
  } else if (delta < DAY) {
    relativeTime = intl.formatMessage(messages.hours, { number: Math.floor(delta / HOUR) });
  } else {
    relativeTime = intl.formatMessage(messages.days, { number: Math.floor(delta / DAY) });
  }

  return relativeTime;
};

export default @injectIntl
class Poll extends ImmutablePureComponent {

  static propTypes = {
    poll: ImmutablePropTypes.map,
    intl: PropTypes.object.isRequired,
    dispatch: PropTypes.func,
    disabled: PropTypes.bool,
  };

  state = {
    selected: {},
  };

  handleOptionChange = e => {
    const { target: { value } } = e;

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
  };

  handleVote = () => {
    if (this.props.disabled) {
      return;
    }

    this.props.dispatch(vote(this.props.poll.get('id'), Object.keys(this.state.selected)));
  };

  handleRefresh = () => {
    if (this.props.disabled) {
      return;
    }

    this.props.dispatch(fetchPoll(this.props.poll.get('id')));
  };

  renderOption (option, optionIndex) {
    const { poll, disabled } = this.props;
    const percent            = (option.get('votes_count') / poll.get('votes_count')) * 100;
    const leading            = poll.get('options').filterNot(other => other.get('title') === option.get('title')).every(other => option.get('votes_count') > other.get('votes_count'));
    const active             = !!this.state.selected[`${optionIndex}`];
    const showResults        = poll.get('voted') || poll.get('expired');

    return (
      <li key={option.get('title')}>
        {showResults && (
          <Motion defaultStyle={{ width: 0 }} style={{ width: spring(percent, { stiffness: 180, damping: 12 }) }}>
            {({ width }) =>
              <span className={classNames('poll__chart', { leading })} style={{ width: `${width}%` }} />
            }
          </Motion>
        )}

        <label className={classNames('poll__text', { selectable: !showResults })}>
          <input
            name='vote-options'
            type={poll.get('multiple') ? 'checkbox' : 'radio'}
            value={optionIndex}
            checked={active}
            onChange={this.handleOptionChange}
            disabled={disabled}
          />

          {!showResults && <span className={classNames('poll__input', { active })} />}
          {showResults && <span className='poll__number'>{Math.floor(percent)}%</span>}

          {option.get('title')}
        </label>
      </li>
    );
  }

  render () {
    const { poll, intl } = this.props;

    if (!poll) {
      return null;
    }

    const timeRemaining = timeRemainingString(intl, new Date(poll.get('expires_at')), intl.now());
    const showResults   = poll.get('voted') || poll.get('expired');
    const disabled      = this.props.disabled || Object.entries(this.state.selected).every(item => !item);

    return (
      <div className='poll'>
        <ul>
          {poll.get('options').map((option, i) => this.renderOption(option, i))}
        </ul>

        <div className='poll__footer'>
          {!showResults && <button className='button button-secondary' disabled={disabled} onClick={this.handleVote}><FormattedMessage id='poll.vote' defaultMessage='Vote' /></button>}
          {showResults && !this.props.disabled && <span><button className='poll__link' onClick={this.handleRefresh}><FormattedMessage id='poll.refresh' defaultMessage='Refresh' /></button> · </span>}
          <FormattedMessage id='poll.total_votes' defaultMessage='{count, plural, one {# vote} other {# votes}}' values={{ count: poll.get('votes_count') }} />  · {timeRemaining}
        </div>
      </div>
    );
  }

}
