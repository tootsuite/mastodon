// @ts-check
import React from 'react';
import { Sparklines, SparklinesCurve } from 'react-sparklines';
import { FormattedMessage } from 'react-intl';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import Permalink from './permalink';
import ShortNumber from 'mastodon/components/short_number';

class SilentErrorBoundary extends React.Component {

  static propTypes = {
    children: PropTypes.node,
  };

  state = {
    error: false,
  };

  componentDidCatch () {
    this.setState({ error: true });
  }

  render () {
    if (this.state.error) {
      return null;
    }

    return this.props.children;
  }

}

/**
 * Used to render counter of how much people are talking about hashtag
 *
 * @type {(displayNumber: JSX.Element, pluralReady: number) => JSX.Element}
 */
const accountsCountRenderer = (displayNumber, pluralReady) => (
  <FormattedMessage
    id='trends.counter_by_accounts'
    defaultMessage='{count, plural, one {{counter} person} other {{counter} people}} talking'
    values={{
      count: pluralReady,
      counter: <strong>{displayNumber}</strong>,
    }}
  />
);

const Hashtag = ({ hashtag }) => (
  <div className='trends__item'>
    <div className='trends__item__name'>
      <Permalink
        href={hashtag.get('url')}
        to={`/timelines/tag/${hashtag.get('name')}`}
      >
        #<span>{hashtag.get('name')}</span>
      </Permalink>

      <ShortNumber
        value={
          hashtag.getIn(['history', 0, 'accounts']) * 1 +
          hashtag.getIn(['history', 1, 'accounts']) * 1
        }
        renderer={accountsCountRenderer}
      />
    </div>

    <div className='trends__item__current'>
      <ShortNumber
        value={
          hashtag.getIn(['history', 0, 'uses']) * 1 +
          hashtag.getIn(['history', 1, 'uses']) * 1
        }
      />
    </div>

    <div className='trends__item__sparkline'>
      <SilentErrorBoundary>
        <Sparklines
          width={50}
          height={28}
          data={hashtag
            .get('history')
            .reverse()
            .map((day) => day.get('uses'))
            .toArray()}
        >
          <SparklinesCurve style={{ fill: 'none' }} />
        </Sparklines>
      </SilentErrorBoundary>
    </div>
  </div>
);

Hashtag.propTypes = {
  hashtag: ImmutablePropTypes.map.isRequired,
};

export default Hashtag;
