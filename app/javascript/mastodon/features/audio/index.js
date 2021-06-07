import React from 'react';
import PropTypes from 'prop-types';
import { defineMessages, injectIntl } from 'react-intl';
import { formatTime } from 'mastodon/features/video';
import Icon from 'mastodon/components/icon';
import classNames from 'classnames';
import { throttle } from 'lodash';
import { getPointerPosition, fileNameFromURL } from 'mastodon/features/video';
import { debounce } from 'lodash';
import Visualizer from './visualizer';

const messages = defineMessages({
  play: { id: 'video.play', defaultMessage: 'Play' },
  pause: { id: 'video.pause', defaultMessage: 'Pause' },
  mute: { id: 'video.mute', defaultMessage: 'Mute sound' },
  unmute: { id: 'video.unmute', defaultMessage: 'Unmute sound' },
  download: { id: 'video.download', defaultMessage: 'Download file' },
});

const TICK_SIZE = 10;
const PADDING   = 180;

@injectIntl
export default class Audio extends React.PureComponent {

  static propTypes = {
    src: PropTypes.string.isRequired,
    alt: PropTypes.string,
    poster: PropTypes.string,
    duration: PropTypes.number,
    width: PropTypes.number,
    height: PropTypes.number,
    editable: PropTypes.bool,
    fullscreen: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    cacheWidth: PropTypes.func,
    backgroundColor: PropTypes.string,
    foregroundColor: PropTypes.string,
    accentColor: PropTypes.string,
    currentTime: PropTypes.number,
    autoPlay: PropTypes.bool,
    volume: PropTypes.number,
    muted: PropTypes.bool,
    deployPictureInPicture: PropTypes.func,
  };

  state = {
    width: this.props.width,
    currentTime: 0,
    buffer: 0,
    duration: null,
    paused: true,
    muted: false,
    volume: 0.5,
    dragging: false,
  };

  constructor (props) {
    super(props);
    this.visualizer = new Visualizer(TICK_SIZE);
  }

  setPlayerRef = c => {
    this.player = c;

    if (this.player) {
      this._setDimensions();
    }
  }

  _pack() {
    return {
      src: this.props.src,
      volume: this.audio.volume,
      muted: this.audio.muted,
      currentTime: this.audio.currentTime,
      poster: this.props.poster,
      backgroundColor: this.props.backgroundColor,
      foregroundColor: this.props.foregroundColor,
      accentColor: this.props.accentColor,
    };
  }

  _setDimensions () {
    const width  = this.player.offsetWidth;
    const height = this.props.fullscreen ? this.player.offsetHeight : (width / (16/9));

    if (this.props.cacheWidth) {
      this.props.cacheWidth(width);
    }

    this.setState({ width, height });
  }

  setSeekRef = c => {
    this.seek = c;
  }

  setVolumeRef = c => {
    this.volume = c;
  }

  setAudioRef = c => {
    this.audio = c;

    if (this.audio) {
      this.setState({ volume: this.audio.volume, muted: this.audio.muted });
    }
  }

  setCanvasRef = c => {
    this.canvas = c;

    this.visualizer.setCanvas(c);
  }

  componentDidMount () {
    window.addEventListener('scroll', this.handleScroll);
    window.addEventListener('resize', this.handleResize, { passive: true });
  }

  componentDidUpdate (prevProps, prevState) {
    if (prevProps.src !== this.props.src || this.state.width !== prevState.width || this.state.height !== prevState.height || prevProps.accentColor !== this.props.accentColor) {
      this._clear();
      this._draw();
    }
  }

  componentWillUnmount () {
    window.removeEventListener('scroll', this.handleScroll);
    window.removeEventListener('resize', this.handleResize);

    if (!this.state.paused && this.audio && this.props.deployPictureInPicture) {
      this.props.deployPictureInPicture('audio', this._pack());
    }
  }

  togglePlay = () => {
    if (!this.audioContext) {
      this._initAudioContext();
    }

    if (this.state.paused) {
      this.setState({ paused: false }, () => this.audio.play());
    } else {
      this.setState({ paused: true }, () => this.audio.pause());
    }
  }

  handleResize = debounce(() => {
    if (this.player) {
      this._setDimensions();
    }
  }, 250, {
    trailing: true,
  });

  handlePlay = () => {
    this.setState({ paused: false });

    if (this.audioContext && this.audioContext.state === 'suspended') {
      this.audioContext.resume();
    }

    this._renderCanvas();
  }

  handlePause = () => {
    this.setState({ paused: true });

    if (this.audioContext) {
      this.audioContext.suspend();
    }
  }

  handleProgress = () => {
    const lastTimeRange = this.audio.buffered.length - 1;

    if (lastTimeRange > -1) {
      this.setState({ buffer: Math.ceil(this.audio.buffered.end(lastTimeRange) / this.audio.duration * 100) });
    }
  }

  toggleMute = () => {
    const muted = !this.state.muted;

    this.setState({ muted }, () => {
      this.audio.muted = muted;
    });
  }

  handleVolumeMouseDown = e => {
    document.addEventListener('mousemove', this.handleMouseVolSlide, true);
    document.addEventListener('mouseup', this.handleVolumeMouseUp, true);
    document.addEventListener('touchmove', this.handleMouseVolSlide, true);
    document.addEventListener('touchend', this.handleVolumeMouseUp, true);

    this.handleMouseVolSlide(e);

    e.preventDefault();
    e.stopPropagation();
  }

  handleVolumeMouseUp = () => {
    document.removeEventListener('mousemove', this.handleMouseVolSlide, true);
    document.removeEventListener('mouseup', this.handleVolumeMouseUp, true);
    document.removeEventListener('touchmove', this.handleMouseVolSlide, true);
    document.removeEventListener('touchend', this.handleVolumeMouseUp, true);
  }

  handleMouseDown = e => {
    document.addEventListener('mousemove', this.handleMouseMove, true);
    document.addEventListener('mouseup', this.handleMouseUp, true);
    document.addEventListener('touchmove', this.handleMouseMove, true);
    document.addEventListener('touchend', this.handleMouseUp, true);

    this.setState({ dragging: true });
    this.audio.pause();
    this.handleMouseMove(e);

    e.preventDefault();
    e.stopPropagation();
  }

  handleMouseUp = () => {
    document.removeEventListener('mousemove', this.handleMouseMove, true);
    document.removeEventListener('mouseup', this.handleMouseUp, true);
    document.removeEventListener('touchmove', this.handleMouseMove, true);
    document.removeEventListener('touchend', this.handleMouseUp, true);

    this.setState({ dragging: false });
    this.audio.play();
  }

  handleMouseMove = throttle(e => {
    const { x } = getPointerPosition(this.seek, e);
    const currentTime = this.audio.duration * x;

    if (!isNaN(currentTime)) {
      this.setState({ currentTime }, () => {
        this.audio.currentTime = currentTime;
      });
    }
  }, 15);

  handleTimeUpdate = () => {
    this.setState({
      currentTime: this.audio.currentTime,
      duration: this.audio.duration,
    });
  }

  handleMouseVolSlide = throttle(e => {
    const { x } = getPointerPosition(this.volume, e);

    if(!isNaN(x)) {
      this.setState({ volume: x }, () => {
        this.audio.volume = x;
      });
    }
  }, 15);

  handleScroll = throttle(() => {
    if (!this.canvas || !this.audio) {
      return;
    }

    const { top, height } = this.canvas.getBoundingClientRect();
    const inView = (top <= (window.innerHeight || document.documentElement.clientHeight)) && (top + height >= 0);

    if (!this.state.paused && !inView) {
      this.audio.pause();

      if (this.props.deployPictureInPicture) {
        this.props.deployPictureInPicture('audio', this._pack());
      }

      this.setState({ paused: true });
    }
  }, 150, { trailing: true });

  handleMouseEnter = () => {
    this.setState({ hovered: true });
  }

  handleMouseLeave = () => {
    this.setState({ hovered: false });
  }

  handleLoadedData = () => {
    const { autoPlay, currentTime, volume, muted } = this.props;

    if (currentTime) {
      this.audio.currentTime = currentTime;
    }

    if (volume !== undefined) {
      this.audio.volume = volume;
    }

    if (muted !== undefined) {
      this.audio.muted = muted;
    }

    if (autoPlay) {
      this.togglePlay();
    }
  }

  _initAudioContext () {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    const context      = new AudioContext();
    const source       = context.createMediaElementSource(this.audio);

    this.visualizer.setAudioContext(context, source);
    source.connect(context.destination);

    this.audioContext = context;
  }

  handleDownload = () => {
    fetch(this.props.src).then(res => res.blob()).then(blob => {
      const element   = document.createElement('a');
      const objectURL = URL.createObjectURL(blob);

      element.setAttribute('href', objectURL);
      element.setAttribute('download', fileNameFromURL(this.props.src));

      document.body.appendChild(element);
      element.click();
      document.body.removeChild(element);

      URL.revokeObjectURL(objectURL);
    }).catch(err => {
      console.error(err);
    });
  }

  _renderCanvas () {
    requestAnimationFrame(() => {
      if (!this.audio) return;

      this.handleTimeUpdate();
      this._clear();
      this._draw();

      if (!this.state.paused) {
        this._renderCanvas();
      }
    });
  }

  _clear() {
    this.visualizer.clear(this.state.width, this.state.height);
  }

  _draw() {
    this.visualizer.draw(this._getCX(), this._getCY(), this._getAccentColor(), this._getRadius(), this._getScaleCoefficient());
  }

  _getRadius () {
    return parseInt(((this.state.height || this.props.height) - (PADDING * this._getScaleCoefficient()) * 2) / 2);
  }

  _getScaleCoefficient () {
    return (this.state.height || this.props.height) / 982;
  }

  _getCX() {
    return Math.floor(this.state.width / 2);
  }

  _getCY() {
    return Math.floor(this._getRadius() + (PADDING * this._getScaleCoefficient()));
  }

  _getAccentColor () {
    return this.props.accentColor || '#ffffff';
  }

  _getBackgroundColor () {
    return this.props.backgroundColor || '#000000';
  }

  _getForegroundColor () {
    return this.props.foregroundColor || '#ffffff';
  }

  seekBy (time) {
    const currentTime = this.audio.currentTime + time;

    if (!isNaN(currentTime)) {
      this.setState({ currentTime }, () => {
        this.audio.currentTime = currentTime;
      });
    }
  }

  handleAudioKeyDown = e => {
    // On the audio element or the seek bar, we can safely use the space bar
    // for playback control because there are no buttons to press

    if (e.key === ' ') {
      e.preventDefault();
      e.stopPropagation();
      this.togglePlay();
    }
  }

  handleKeyDown = e => {
    switch(e.key) {
    case 'k':
      e.preventDefault();
      e.stopPropagation();
      this.togglePlay();
      break;
    case 'm':
      e.preventDefault();
      e.stopPropagation();
      this.toggleMute();
      break;
    case 'j':
      e.preventDefault();
      e.stopPropagation();
      this.seekBy(-10);
      break;
    case 'l':
      e.preventDefault();
      e.stopPropagation();
      this.seekBy(10);
      break;
    }
  }

  render () {
    const { src, intl, alt, editable, autoPlay } = this.props;
    const { paused, muted, volume, currentTime, duration, buffer, dragging } = this.state;
    const progress = Math.min((currentTime / duration) * 100, 100);

    return (
      <div className={classNames('audio-player', { editable })} ref={this.setPlayerRef} style={{ backgroundColor: this._getBackgroundColor(), color: this._getForegroundColor(), width: '100%', height: this.props.fullscreen ? '100%' : (this.state.height || this.props.height) }} onMouseEnter={this.handleMouseEnter} onMouseLeave={this.handleMouseLeave} tabIndex='0' onKeyDown={this.handleKeyDown}>
        <audio
          src={src}
          ref={this.setAudioRef}
          preload={autoPlay ? 'auto' : 'none'}
          onPlay={this.handlePlay}
          onPause={this.handlePause}
          onProgress={this.handleProgress}
          onLoadedData={this.handleLoadedData}
          crossOrigin='anonymous'
        />

        <canvas
          role='button'
          tabIndex='0'
          className='audio-player__canvas'
          width={this.state.width}
          height={this.state.height}
          style={{ width: '100%', position: 'absolute', top: 0, left: 0 }}
          ref={this.setCanvasRef}
          onClick={this.togglePlay}
          onKeyDown={this.handleAudioKeyDown}
          title={alt}
          aria-label={alt}
        />

        <img
          src={this.props.poster}
          alt=''
          width={(this._getRadius() - TICK_SIZE) * 2}
          height={(this._getRadius() - TICK_SIZE) * 2}
          style={{ position: 'absolute', left: this._getCX(), top: this._getCY(), transform: 'translate(-50%, -50%)', borderRadius: '50%', pointerEvents: 'none' }}
        />

        <div className='video-player__seek' onMouseDown={this.handleMouseDown} ref={this.setSeekRef}>
          <div className='video-player__seek__buffer' style={{ width: `${buffer}%` }} />
          <div className='video-player__seek__progress' style={{ width: `${progress}%`, backgroundColor: this._getAccentColor() }} />

          <span
            className={classNames('video-player__seek__handle', { active: dragging })}
            tabIndex='0'
            style={{ left: `${progress}%`, backgroundColor: this._getAccentColor() }}
            onKeyDown={this.handleAudioKeyDown}
          />
        </div>

        <div className='video-player__controls active'>
          <div className='video-player__buttons-bar'>
            <div className='video-player__buttons left'>
              <button type='button' title={intl.formatMessage(paused ? messages.play : messages.pause)} aria-label={intl.formatMessage(paused ? messages.play : messages.pause)} className='player-button' onClick={this.togglePlay}><Icon id={paused ? 'play' : 'pause'} fixedWidth /></button>
              <button type='button' title={intl.formatMessage(muted ? messages.unmute : messages.mute)} aria-label={intl.formatMessage(muted ? messages.unmute : messages.mute)} className='player-button' onClick={this.toggleMute}><Icon id={muted ? 'volume-off' : 'volume-up'} fixedWidth /></button>

              <div className={classNames('video-player__volume', { active: this.state.hovered })} ref={this.setVolumeRef} onMouseDown={this.handleVolumeMouseDown}>
                <div className='video-player__volume__current' style={{ width: `${volume * 100}%`, backgroundColor: this._getAccentColor() }} />

                <span
                  className='video-player__volume__handle'
                  tabIndex='0'
                  style={{ left: `${volume * 100}%`, backgroundColor: this._getAccentColor() }}
                />
              </div>

              <span className='video-player__time'>
                <span className='video-player__time-current'>{formatTime(Math.floor(currentTime))}</span>
                <span className='video-player__time-sep'>/</span>
                <span className='video-player__time-total'>{formatTime(Math.floor(this.state.duration || this.props.duration))}</span>
              </span>
            </div>

            <div className='video-player__buttons right'>
              <a title={intl.formatMessage(messages.download)} aria-label={intl.formatMessage(messages.download)} className='video-player__download__icon player-button' href={this.props.src} download>
                <Icon id={'download'} fixedWidth />
              </a>
            </div>
          </div>
        </div>
      </div>
    );
  }

}
