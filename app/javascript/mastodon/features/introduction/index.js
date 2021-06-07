import React from 'react';
import PropTypes from 'prop-types';
import ReactSwipeableViews from 'react-swipeable-views';
import classNames from 'classnames';
import { connect } from 'react-redux';
import { FormattedMessage } from 'react-intl';
import { closeOnboarding } from '../../actions/onboarding';
import screenHello from '../../../images/screen_hello.svg';
import screenFederation from '../../../images/screen_federation.svg';
import screenInteractions from '../../../images/screen_interactions.svg';
import logoTransparent from '../../../images/logo_transparent.svg';
import { disableSwiping } from 'mastodon/initial_state';

const FrameWelcome = ({ domain, onNext }) => (
  <div className='introduction__frame'>
    <div className='introduction__illustration' style={{ background: `url(${logoTransparent}) no-repeat center center / auto 80%` }}>
      <img src={screenHello} alt='' />
    </div>

    <div className='introduction__text introduction__text--centered'>
      <h3><FormattedMessage id='introduction.welcome.headline' defaultMessage='First steps' /></h3>
      <p><FormattedMessage id='introduction.welcome.text' defaultMessage="Welcome to the fediverse! In a few moments, you'll be able to broadcast messages and talk to your friends across a wide variety of servers. But this server, {domain}, is special—it hosts your profile, so remember its name." values={{ domain: <code>{domain}</code> }} /></p>
    </div>

    <div className='introduction__action'>
      <button className='button' onClick={onNext}><FormattedMessage id='introduction.welcome.action' defaultMessage="Let's go!" /></button>
    </div>
  </div>
);

FrameWelcome.propTypes = {
  domain: PropTypes.string.isRequired,
  onNext: PropTypes.func.isRequired,
};

const FrameFederation = ({ onNext }) => (
  <div className='introduction__frame'>
    <div className='introduction__illustration'>
      <img src={screenFederation} alt='' />
    </div>

    <div className='introduction__text introduction__text--columnized'>
      <div>
        <h3><FormattedMessage id='introduction.federation.home.headline' defaultMessage='Home' /></h3>
        <p><FormattedMessage id='introduction.federation.home.text' defaultMessage='Posts from people you follow will appear in your home feed. You can follow anyone on any server!' /></p>
      </div>

      <div>
        <h3><FormattedMessage id='introduction.federation.local.headline' defaultMessage='Local' /></h3>
        <p><FormattedMessage id='introduction.federation.local.text' defaultMessage='Public posts from people on the same server as you will appear in the local timeline.' /></p>
      </div>

      <div>
        <h3><FormattedMessage id='introduction.federation.federated.headline' defaultMessage='Federated' /></h3>
        <p><FormattedMessage id='introduction.federation.federated.text' defaultMessage='Public posts from other servers of the fediverse will appear in the federated timeline.' /></p>
      </div>
    </div>

    <div className='introduction__action'>
      <button className='button' onClick={onNext}><FormattedMessage id='introduction.federation.action' defaultMessage='Next' /></button>
    </div>
  </div>
);

FrameFederation.propTypes = {
  onNext: PropTypes.func.isRequired,
};

const FrameInteractions = ({ onNext }) => (
  <div className='introduction__frame'>
    <div className='introduction__illustration'>
      <img src={screenInteractions} alt='' />
    </div>

    <div className='introduction__text introduction__text--columnized'>
      <div>
        <h3><FormattedMessage id='introduction.interactions.reply.headline' defaultMessage='Reply' /></h3>
        <p><FormattedMessage id='introduction.interactions.reply.text' defaultMessage="You can reply to other people's and your own toots, which will chain them together in a conversation." /></p>
      </div>

      <div>
        <h3><FormattedMessage id='introduction.interactions.reblog.headline' defaultMessage='Boost' /></h3>
        <p><FormattedMessage id='introduction.interactions.reblog.text' defaultMessage="You can share other people's toots with your followers by boosting them." /></p>
      </div>

      <div>
        <h3><FormattedMessage id='introduction.interactions.favourite.headline' defaultMessage='Favourite' /></h3>
        <p><FormattedMessage id='introduction.interactions.favourite.text' defaultMessage='You can save a toot for later, and let the author know that you liked it, by favouriting it.' /></p>
      </div>
    </div>

    <div className='introduction__action'>
      <button className='button' onClick={onNext}><FormattedMessage id='introduction.interactions.action' defaultMessage='Finish toot-orial!' /></button>
    </div>
  </div>
);

FrameInteractions.propTypes = {
  onNext: PropTypes.func.isRequired,
};

@connect(state => ({ domain: state.getIn(['meta', 'domain']) }))
export default class Introduction extends React.PureComponent {

  static propTypes = {
    domain: PropTypes.string.isRequired,
    dispatch: PropTypes.func.isRequired,
  };

  state = {
    currentIndex: 0,
  };

  componentWillMount () {
    this.pages = [
      <FrameWelcome domain={this.props.domain} onNext={this.handleNext} />,
      <FrameFederation onNext={this.handleNext} />,
      <FrameInteractions onNext={this.handleFinish} />,
    ];
  }

  componentDidMount() {
    window.addEventListener('keyup', this.handleKeyUp);
  }

  componentWillUnmount() {
    window.addEventListener('keyup', this.handleKeyUp);
  }

  handleDot = (e) => {
    const i = Number(e.currentTarget.getAttribute('data-index'));
    e.preventDefault();
    this.setState({ currentIndex: i });
  }

  handlePrev = () => {
    this.setState(({ currentIndex }) => ({
      currentIndex: Math.max(0, currentIndex - 1),
    }));
  }

  handleNext = () => {
    const { pages } = this;

    this.setState(({ currentIndex }) => ({
      currentIndex: Math.min(currentIndex + 1, pages.length - 1),
    }));
  }

  handleSwipe = (index) => {
    this.setState({ currentIndex: index });
  }

  handleFinish = () => {
    this.props.dispatch(closeOnboarding());
  }

  handleKeyUp = ({ key }) => {
    switch (key) {
    case 'ArrowLeft':
      this.handlePrev();
      break;
    case 'ArrowRight':
      this.handleNext();
      break;
    }
  }

  render () {
    const { currentIndex } = this.state;
    const { pages } = this;

    return (
      <div className='introduction'>
        <ReactSwipeableViews index={currentIndex} onChangeIndex={this.handleSwipe} disabled={disableSwiping} className='introduction__pager'>
          {pages.map((page, i) => (
            <div key={i} className={classNames('introduction__frame-wrapper', { 'active': i === currentIndex })}>{page}</div>
          ))}
        </ReactSwipeableViews>

        <div className='introduction__dots'>
          {pages.map((_, i) => (
            <div
              key={`dot-${i}`}
              role='button'
              tabIndex='0'
              data-index={i}
              onClick={this.handleDot}
              className={classNames('introduction__dot', { active: i === currentIndex })}
            />
          ))}
        </div>
      </div>
    );
  }

}
