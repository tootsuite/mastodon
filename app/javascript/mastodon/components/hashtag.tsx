import React from 'react';
import { Sparklines, SparklinesCurve } from 'react-sparklines';
import { FormattedMessage } from 'react-intl';
import PropTypes from 'prop-types';
import Permalink from './permalink';
// @ts-expect-error
import ShortNumber from 'mastodon/components/short_number';
import { Hashtag as HashtagType } from '../../types/resources';

class SilentErrorBoundary extends React.Component {

  static propTypes = {
    children: PropTypes.node,
  };

  state = {
    error: false,
  };

  componentDidCatch() {
    this.setState({ error: true });
  }

  render() {
    if (this.state.error) {
      return null;
    }

    return this.props.children;
  }

}

type accountsCountRenderer = (displayNumber: React.ReactNode, pluralReady: number) => React.ReactNode
const accountsCountRenderer: accountsCountRenderer = (displayNumber, pluralReady) => (
  <FormattedMessage
    id='trends.counter_by_accounts'
    defaultMessage='{count, plural, one {{counter} person} other {{counter} people}} talking'
    values={{
      count: pluralReady,
      counter: <strong>{displayNumber}</strong>,
    }}
  />
);

type Props = {
  hashtag: HashtagType;
}
const Hashtag: React.FC<Props> = ({ hashtag }) => (
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
          hashtag.get('history')[0].get('accounts') * 1 +
          hashtag.get('history')[1].get('accounts') * 1
        }
        renderer={accountsCountRenderer}
      />
    </div>

    <div className='trends__item__current'>
      <ShortNumber
        value={
          hashtag.get('history')[0].get('uses') * 1 +
          hashtag.get('history')[1].get('uses') * 1
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
            // @ts-expect-error
            .toArray()}
        >
          <SparklinesCurve style={{ fill: 'none' }} />
        </Sparklines>
      </SilentErrorBoundary>
    </div>
  </div>
);

export default Hashtag;
