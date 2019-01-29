import React from 'react';
import PropTypes from 'prop-types';
import Icon from 'mastodon/components/icon';
import { removePictureInPicture } from 'mastodon/actions/picture_in_picture';
import { connect } from 'react-redux';
import { debounce } from 'lodash';
import { FormattedMessage } from 'react-intl';

@connect
export default class PictureInPicturePlaceholder extends React.PureComponent {

  static propTypes = {
    width: PropTypes.number,
    dispatch: PropTypes.func.isRequired,
  };

  state = {
    width: this.props.width,
    height: this.props.width && (this.props.width / (16/9)),
  };

  handleClick = () => {
    const { dispatch } = this.props;
    dispatch(removePictureInPicture());
  }

  setRef = c => {
    this.node = c;

    if (this.node) {
      this._setDimensions();
    }
  }

  _setDimensions () {
    const width  = this.node.offsetWidth;
    const height = width / (16/9);

    this.setState({ width, height });
  }

  componentDidMount () {
    window.addEventListener('resize', this.handleResize, { passive: true });
  }

  componentWillUnmount () {
    window.removeEventListener('resize', this.handleResize);
  }

  handleResize = debounce(() => {
    if (this.node) {
      this._setDimensions();
    }
  }, 250, {
    trailing: true,
  });

  render () {
    const { height } = this.state;

    return (
      <div ref={this.setRef} className='picture-in-picture-placeholder' style={{ height }} role='button' tabIndex='0' onClick={this.handleClick}>
        <Icon id='window-restore' />
        <FormattedMessage id='picture_in_picture.restore' defaultMessage='Put it back' />
      </div>
    );
  }

}
