import { PureComponent } from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { title } from 'mastodon/initial_state';

const mapStateToProps = state => ({
  unread: state.getIn(['missed_updates', 'unread']),
});

@connect(mapStateToProps)
export default class DocumentTitle extends PureComponent {

  static propTypes = {
    unread: PropTypes.number.isRequired,
  };

  componentDidMount () {
    this._sideEffects();
  }

  componentDidUpdate() {
    this._sideEffects();
  }

  _sideEffects () {
    const { unread } = this.props;

    if (unread > 99) {
      document.title = `(*) ${title}`;
    } else if (unread > 0) {
      document.title = `(${unread}) ${title}`;
    } else {
      document.title = title;
    }
  }

  render () {
    return null;
  }

}
