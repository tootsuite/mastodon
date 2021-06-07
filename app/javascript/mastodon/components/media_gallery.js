import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import { is } from 'immutable';
import IconButton from './icon_button';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import { isIOS } from '../is_mobile';
import classNames from 'classnames';
import { autoPlayGif, cropImages, displayMedia, useBlurhash } from '../initial_state';
import { debounce } from 'lodash';
import Blurhash from 'mastodon/components/blurhash';

const messages = defineMessages({
  toggle_visible: { id: 'media_gallery.toggle_visible', defaultMessage: '{number, plural, one {Hide image} other {Hide images}}' },
});

class Item extends React.PureComponent {

  static propTypes = {
    attachment: ImmutablePropTypes.map.isRequired,
    standalone: PropTypes.bool,
    index: PropTypes.number.isRequired,
    size: PropTypes.number.isRequired,
    onClick: PropTypes.func.isRequired,
    displayWidth: PropTypes.number,
    visible: PropTypes.bool.isRequired,
    autoplay: PropTypes.bool,
  };

  static defaultProps = {
    standalone: false,
    index: 0,
    size: 1,
  };

  state = {
    loaded: false,
  };

  handleMouseEnter = (e) => {
    if (this.hoverToPlay()) {
      e.target.play();
    }
  }

  handleMouseLeave = (e) => {
    if (this.hoverToPlay()) {
      e.target.pause();
      e.target.currentTime = 0;
    }
  }

  getAutoPlay() {
    return this.props.autoplay || autoPlayGif;
  }

  hoverToPlay () {
    const { attachment } = this.props;
    return !this.getAutoPlay() && attachment.get('type') === 'gifv';
  }

  handleClick = (e) => {
    const { index, onClick } = this.props;

    if (e.button === 0 && !(e.ctrlKey || e.metaKey)) {
      if (this.hoverToPlay()) {
        e.target.pause();
        e.target.currentTime = 0;
      }
      e.preventDefault();
      onClick(index);
    }

    e.stopPropagation();
  }

  handleImageLoad = () => {
    this.setState({ loaded: true });
  }

  render () {
    const { attachment, index, size, standalone, displayWidth, visible } = this.props;

    let width  = 50;
    let height = 100;
    let top    = 'auto';
    let left   = 'auto';
    let bottom = 'auto';
    let right  = 'auto';

    if (size === 1) {
      width = 100;
    }

    if (size === 4 || (size === 3 && index > 0)) {
      height = 50;
    }

    if (size === 2) {
      if (index === 0) {
        right = '2px';
      } else {
        left = '2px';
      }
    } else if (size === 3) {
      if (index === 0) {
        right = '2px';
      } else if (index > 0) {
        left = '2px';
      }

      if (index === 1) {
        bottom = '2px';
      } else if (index > 1) {
        top = '2px';
      }
    } else if (size === 4) {
      if (index === 0 || index === 2) {
        right = '2px';
      }

      if (index === 1 || index === 3) {
        left = '2px';
      }

      if (index < 2) {
        bottom = '2px';
      } else {
        top = '2px';
      }
    }

    let thumbnail = '';

    if (attachment.get('type') === 'unknown') {
      return (
        <div className={classNames('media-gallery__item', { standalone })} key={attachment.get('id')} style={{ left: left, top: top, right: right, bottom: bottom, width: `${width}%`, height: `${height}%` }}>
          <a className='media-gallery__item-thumbnail' href={attachment.get('remote_url') || attachment.get('url')} style={{ cursor: 'pointer' }} title={attachment.get('description')} target='_blank' rel='noopener noreferrer'>
            <Blurhash
              hash={attachment.get('blurhash')}
              className='media-gallery__preview'
              dummy={!useBlurhash}
            />
          </a>
        </div>
      );
    } else if (attachment.get('type') === 'image') {
      const previewUrl   = attachment.get('preview_url');
      const previewWidth = attachment.getIn(['meta', 'small', 'width']);

      const originalUrl   = attachment.get('url');
      const originalWidth = attachment.getIn(['meta', 'original', 'width']);

      const hasSize = typeof originalWidth === 'number' && typeof previewWidth === 'number';

      const srcSet = hasSize ? `${originalUrl} ${originalWidth}w, ${previewUrl} ${previewWidth}w` : null;
      const sizes  = hasSize && (displayWidth > 0) ? `${displayWidth * (width / 100)}px` : null;

      const focusX = attachment.getIn(['meta', 'focus', 'x']) || 0;
      const focusY = attachment.getIn(['meta', 'focus', 'y']) || 0;
      const x      = ((focusX /  2) + .5) * 100;
      const y      = ((focusY / -2) + .5) * 100;

      thumbnail = (
        <a
          className='media-gallery__item-thumbnail'
          href={attachment.get('remote_url') || originalUrl}
          onClick={this.handleClick}
          target='_blank'
          rel='noopener noreferrer'
        >
          <img
            src={previewUrl}
            srcSet={srcSet}
            sizes={sizes}
            alt={attachment.get('description')}
            title={attachment.get('description')}
            style={{ objectPosition: `${x}% ${y}%` }}
            onLoad={this.handleImageLoad}
          />
        </a>
      );
    } else if (attachment.get('type') === 'gifv') {
      const autoPlay = !isIOS() && this.getAutoPlay();

      thumbnail = (
        <div className={classNames('media-gallery__gifv', { autoplay: autoPlay })}>
          <video
            className='media-gallery__item-gifv-thumbnail'
            aria-label={attachment.get('description')}
            title={attachment.get('description')}
            role='application'
            src={attachment.get('url')}
            onClick={this.handleClick}
            onMouseEnter={this.handleMouseEnter}
            onMouseLeave={this.handleMouseLeave}
            autoPlay={autoPlay}
            loop
            muted
          />

          <span className='media-gallery__gifv__label'>GIF</span>
        </div>
      );
    }

    return (
      <div className={classNames('media-gallery__item', { standalone })} key={attachment.get('id')} style={{ left: left, top: top, right: right, bottom: bottom, width: `${width}%`, height: `${height}%` }}>
        <Blurhash
          hash={attachment.get('blurhash')}
          dummy={!useBlurhash}
          className={classNames('media-gallery__preview', {
            'media-gallery__preview--hidden': visible && this.state.loaded,
          })}
        />
        {visible && thumbnail}
      </div>
    );
  }

}

@injectIntl
export default class MediaGallery extends React.PureComponent {

  static propTypes = {
    sensitive: PropTypes.bool,
    standalone: PropTypes.bool,
    media: ImmutablePropTypes.list.isRequired,
    size: PropTypes.object,
    height: PropTypes.number.isRequired,
    onOpenMedia: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
    defaultWidth: PropTypes.number,
    cacheWidth: PropTypes.func,
    visible: PropTypes.bool,
    autoplay: PropTypes.bool,
    onToggleVisibility: PropTypes.func,
  };

  static defaultProps = {
    standalone: false,
  };

  state = {
    visible: this.props.visible !== undefined ? this.props.visible : (displayMedia !== 'hide_all' && !this.props.sensitive || displayMedia === 'show_all'),
    width: this.props.defaultWidth,
  };

  componentDidMount () {
    window.addEventListener('resize', this.handleResize, { passive: true });
  }

  componentWillUnmount () {
    window.removeEventListener('resize', this.handleResize);
  }

  componentWillReceiveProps (nextProps) {
    if (!is(nextProps.media, this.props.media) && nextProps.visible === undefined) {
      this.setState({ visible: displayMedia !== 'hide_all' && !nextProps.sensitive || displayMedia === 'show_all' });
    } else if (!is(nextProps.visible, this.props.visible) && nextProps.visible !== undefined) {
      this.setState({ visible: nextProps.visible });
    }
  }

  handleResize = debounce(() => {
    if (this.node) {
      this._setDimensions();
    }
  }, 250, {
    trailing: true,
  });

  handleOpen = () => {
    if (this.props.onToggleVisibility) {
      this.props.onToggleVisibility();
    } else {
      this.setState({ visible: !this.state.visible });
    }
  }

  handleClick = (index) => {
    this.props.onOpenMedia(this.props.media, index);
  }

  handleRef = c => {
    this.node = c;

    if (this.node) {
      this._setDimensions();
    }
  }

  _setDimensions () {
    const width = this.node.offsetWidth;

    // offsetWidth triggers a layout, so only calculate when we need to
    if (this.props.cacheWidth) {
      this.props.cacheWidth(width);
    }

    this.setState({
      width: width,
    });
  }

  isFullSizeEligible() {
    const { media } = this.props;
    return media.size === 1 && media.getIn([0, 'meta', 'small', 'aspect']);
  }

  render () {
    const { media, intl, sensitive, height, defaultWidth, standalone, autoplay } = this.props;
    const { visible } = this.state;

    const width = this.state.width || defaultWidth;

    let children, spoilerButton;

    const style = {};

    if (this.isFullSizeEligible() && (standalone || !cropImages)) {
      if (width) {
        style.height = width / this.props.media.getIn([0, 'meta', 'small', 'aspect']);
      }
    } else if (width) {
      style.height = width / (16/9);
    } else {
      style.height = height;
    }

    const size     = media.take(4).size;
    const uncached = media.every(attachment => attachment.get('type') === 'unknown');

    if (standalone && this.isFullSizeEligible()) {
      children = <Item standalone autoplay={autoplay} onClick={this.handleClick} attachment={media.get(0)} displayWidth={width} visible={visible} />;
    } else {
      children = media.take(4).map((attachment, i) => <Item key={attachment.get('id')} autoplay={autoplay} onClick={this.handleClick} attachment={attachment} index={i} size={size} displayWidth={width} visible={visible || uncached} />);
    }

    if (uncached) {
      spoilerButton = (
        <button type='button' disabled className='spoiler-button__overlay'>
          <span className='spoiler-button__overlay__label'><FormattedMessage id='status.uncached_media_warning' defaultMessage='Not available' /></span>
        </button>
      );
    } else if (visible) {
      spoilerButton = <IconButton title={intl.formatMessage(messages.toggle_visible, { number: size })} icon='eye-slash' overlay onClick={this.handleOpen} />;
    } else {
      spoilerButton = (
        <button type='button' onClick={this.handleOpen} className='spoiler-button__overlay'>
          <span className='spoiler-button__overlay__label'>{sensitive ? <FormattedMessage id='status.sensitive_warning' defaultMessage='Sensitive content' /> : <FormattedMessage id='status.media_hidden' defaultMessage='Media hidden' />}</span>
        </button>
      );
    }

    return (
      <div className='media-gallery' style={style} ref={this.handleRef}>
        <div className={classNames('spoiler-button', { 'spoiler-button--minified': visible && !uncached, 'spoiler-button--click-thru': uncached })}>
          {spoilerButton}
        </div>

        {children}
      </div>
    );
  }

}
