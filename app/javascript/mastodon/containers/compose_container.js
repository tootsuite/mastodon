import React from 'react';
import { Provider } from 'react-redux';
import PropTypes from 'prop-types';
import configureStore from '../store/configureStore';
import { hydrateStore } from '../actions/store';
import { IntlProvider } from 'react-intl';
import { getLocale } from '../locales';
import Compose from '../features/standalone/compose';
import initialState from '../initial_state';
import { fetchCustomEmojis } from '../actions/custom_emojis';

const { messages } = getLocale();

const store = configureStore();

if (initialState) {
  store.dispatch(hydrateStore(initialState));
}

store.dispatch(fetchCustomEmojis());

export default class TimelineContainer extends React.PureComponent {

  static propTypes = {
    locale: PropTypes.string.isRequired,
  };

  render () {
    const { locale } = this.props;

    return (
      <IntlProvider locale={locale} messages={messages} textComponent='span'>
        <Provider store={store}>
          <Compose />
        </Provider>
      </IntlProvider>
    );
  }

}
