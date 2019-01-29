import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import Video from 'mastodon/features/video';
import Audio from 'mastodon/features/audio';
import { removePictureInPicture } from 'mastodon/actions/picture_in_picture';
import Header from './components/header';
import Footer from './components/footer';

const mapStateToProps = state => ({
  ...state.get('picture_in_picture'),
});

@connect(mapStateToProps)
export default class PictureInPicture extends React.Component {

  static propTypes = {
    statusId: PropTypes.string,
    accountId: PropTypes.string,
    type: PropTypes.string,
    src: PropTypes.string,
    muted: PropTypes.bool,
    volume: PropTypes.number,
    currentTime: PropTypes.number,
    poster: PropTypes.string,
    backgroundColor: PropTypes.string,
    foregroundColor: PropTypes.string,
    accentColor: PropTypes.string,
    dispatch: PropTypes.func.isRequired,
  };

  handleClose = () => {
    const { dispatch } = this.props;
    dispatch(removePictureInPicture());
  }

  render () {
    const { type, src, currentTime, accountId, statusId } = this.props;

    if (!currentTime) {
      return null;
    }

    let player;

    if (type === 'video') {
      player = (
        <Video
          src={src}
          currentTime={this.props.currentTime}
          volume={this.props.volume}
          muted={this.props.muted}
          autoPlay
          inline
          alwaysVisible
        />
      );
    } else if (type === 'audio') {
      player = (
        <Audio
          src={src}
          currentTime={this.props.currentTime}
          volume={this.props.volume}
          muted={this.props.muted}
          poster={this.props.poster}
          backgroundColor={this.props.backgroundColor}
          foregroundColor={this.props.foregroundColor}
          accentColor={this.props.accentColor}
          autoPlay
        />
      );
    }

    return (
      <div className='picture-in-picture'>
        <Header accountId={accountId} statusId={statusId} onClose={this.handleClose} />

        {player}

        <Footer statusId={statusId} />
      </div>
    );
  }

}
