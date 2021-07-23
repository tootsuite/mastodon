import React, { Fragment } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import PropTypes from 'prop-types';
import configureStore from '../store/configureStore';
import { hydrateStore } from '../actions/store';
import { IntlProvider } from 'react-intl';
import { getLocale } from '../locales';
import PublicTimeline from '../features/standalone/public_timeline';
import HashtagTimeline from '../features/standalone/hashtag_timeline';
import ModalContainer from '../features/ui/containers/modal_container';
import initialState from '../initial_state';

const { messages } = getLocale();

const store = configureStore();

if (initialState) {
  store.dispatch(hydrateStore(initialState));
}

export default class TimelineContainer extends React.PureComponent {

  static propTypes = {
    locale: PropTypes.string.isRequired,
    hashtag: PropTypes.string,
    local: PropTypes.bool,
  };

  static defaultProps = {
    local: !initialState.settings.known_fediverse,
  };

  render () {
    const { locale, hashtag, local } = this.props;

    let timeline;

    if (hashtag) {
      timeline = <HashtagTimeline hashtag={hashtag} local={local} />;
    } else {
      timeline = <PublicTimeline local={local} />;
    }

    return (
      <IntlProvider locale={locale} messages={messages} textComponent='span'>
        <Provider store={store}>
          <Fragment>
            {timeline}

            {ReactDOM.createPortal(
              <ModalContainer />,
              document.getElementById('modal-container'),
            )}
          </Fragment>
        </Provider>
      </IntlProvider>
    );
  }

}
