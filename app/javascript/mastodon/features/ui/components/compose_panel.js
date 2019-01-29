import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import SearchContainer from 'mastodon/features/compose/containers/search_container';
import ComposeFormContainer from 'mastodon/features/compose/containers/compose_form_container';
import NavigationContainer from 'mastodon/features/compose/containers/navigation_container';
import LinkFooter from './link_footer';
import { changeComposing } from 'mastodon/actions/compose';

@connect()
export default class ComposePanel extends React.PureComponent {

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
  };

  onFocus = () => {
    this.props.dispatch(changeComposing(true));
  }

  onBlur = () => {
    this.props.dispatch(changeComposing(false));
  }

  render() {
    return (
      <div className='compose-panel' onFocus={this.onFocus}>
        <SearchContainer openInRoute />
        <NavigationContainer onClose={this.onBlur} />
        <ComposeFormContainer singleColumn />
        <LinkFooter withHotkeys />
      </div>
    );
  }

}
