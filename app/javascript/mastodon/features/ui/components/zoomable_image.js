import React from 'react';
import PropTypes from 'prop-types';
import IconButton from 'mastodon/components/icon_button';
import { defineMessages, injectIntl } from 'react-intl';

const messages = defineMessages({
  compress: { id: 'lightbox.compress', defaultMessage: 'Compress image view box' },
  expand: { id: 'lightbox.expand', defaultMessage: 'Expand image view box' },
});

const MIN_SCALE = 1;
const MAX_SCALE = 4;
const NAV_BAR_HEIGHT = 66;

const getMidpoint = (p1, p2) => ({
  x: (p1.clientX + p2.clientX) / 2,
  y: (p1.clientY + p2.clientY) / 2,
});

const getDistance = (p1, p2) =>
  Math.sqrt(Math.pow(p1.clientX - p2.clientX, 2) + Math.pow(p1.clientY - p2.clientY, 2));

const clamp = (min, max, value) => Math.min(max, Math.max(min, value));

// Normalizing mousewheel speed across browsers
// copy from: https://github.com/facebookarchive/fixed-data-table/blob/master/src/vendor_upstream/dom/normalizeWheel.js
const normalizeWheel = event => {
  // Reasonable defaults
  const PIXEL_STEP = 10;
  const LINE_HEIGHT = 40;
  const PAGE_HEIGHT = 800;

  let sX = 0,
    sY = 0, // spinX, spinY
    pX = 0,
    pY = 0; // pixelX, pixelY

  // Legacy
  if ('detail' in event) {
    sY = event.detail;
  }
  if ('wheelDelta' in event) {
    sY = -event.wheelDelta / 120;
  }
  if ('wheelDeltaY' in event) {
    sY = -event.wheelDeltaY / 120;
  }
  if ('wheelDeltaX' in event) {
    sX = -event.wheelDeltaX / 120;
  }

  // side scrolling on FF with DOMMouseScroll
  if ('axis' in event && event.axis === event.HORIZONTAL_AXIS) {
    sX = sY;
    sY = 0;
  }

  pX = sX * PIXEL_STEP;
  pY = sY * PIXEL_STEP;

  if ('deltaY' in event) {
    pY = event.deltaY;
  }
  if ('deltaX' in event) {
    pX = event.deltaX;
  }

  if ((pX || pY) && event.deltaMode) {
    if (event.deltaMode === 1) { // delta in LINE units
      pX *= LINE_HEIGHT;
      pY *= LINE_HEIGHT;
    } else { // delta in PAGE units
      pX *= PAGE_HEIGHT;
      pY *= PAGE_HEIGHT;
    }
  }

  // Fall-back if spin cannot be determined
  if (pX && !sX) {
    sX = (pX < 1) ? -1 : 1;
  }
  if (pY && !sY) {
    sY = (pY < 1) ? -1 : 1;
  }

  return {
    spinX: sX,
    spinY: sY,
    pixelX: pX,
    pixelY: pY,
  };
};

@injectIntl
export default class ZoomableImage extends React.PureComponent {

  static propTypes = {
    alt: PropTypes.string,
    src: PropTypes.string.isRequired,
    width: PropTypes.number,
    height: PropTypes.number,
    onClick: PropTypes.func,
    zoomButtonHidden: PropTypes.bool,
    intl: PropTypes.object.isRequired,
  }

  static defaultProps = {
    alt: '',
    width: null,
    height: null,
  };

  state = {
    scale: MIN_SCALE,
    zoomMatrix: {
      type: null, // 'width' 'height'
      fullScreen: null, // bool
      rate: null, // full screen scale rate
      clientWidth: null,
      clientHeight: null,
      offsetWidth: null,
      offsetHeight: null,
      clientHeightFixed: null,
      scrollTop: null,
      scrollLeft: null,
      translateX: null,
      translateY: null,
    },
    zoomState: 'expand', // 'expand' 'compress'
    navigationHidden: false,
    dragPosition: { top: 0, left: 0, x: 0, y: 0 },
    dragged: false,
    lockScroll: { x: 0, y: 0 },
    lockTranslate: { x: 0, y: 0 },
  }

  removers = [];
  container = null;
  image = null;
  lastTouchEndTime = 0;
  lastDistance = 0;

  componentDidMount () {
    let handler = this.handleTouchStart;
    this.container.addEventListener('touchstart', handler);
    this.removers.push(() => this.container.removeEventListener('touchstart', handler));
    handler = this.handleTouchMove;
    // on Chrome 56+, touch event listeners will default to passive
    // https://www.chromestatus.com/features/5093566007214080
    this.container.addEventListener('touchmove', handler, { passive: false });
    this.removers.push(() => this.container.removeEventListener('touchend', handler));

    handler = this.mouseDownHandler;
    this.container.addEventListener('mousedown', handler);
    this.removers.push(() => this.container.removeEventListener('mousedown', handler));

    handler = this.mouseWheelHandler;
    this.container.addEventListener('wheel', handler);
    this.removers.push(() => this.container.removeEventListener('wheel', handler));
    // Old Chrome
    this.container.addEventListener('mousewheel', handler);
    this.removers.push(() => this.container.removeEventListener('mousewheel', handler));
    // Old Firefox
    this.container.addEventListener('DOMMouseScroll', handler);
    this.removers.push(() => this.container.removeEventListener('DOMMouseScroll', handler));

    this.initZoomMatrix();
  }

  componentWillUnmount () {
    this.removeEventListeners();
  }

  componentDidUpdate () {
    this.setState({ zoomState: this.state.scale >= this.state.zoomMatrix.rate ? 'compress' : 'expand' });

    if (this.state.scale === MIN_SCALE) {
      this.container.style.removeProperty('cursor');
    }
  }

  UNSAFE_componentWillReceiveProps () {
    // reset when slide to next image
    if (this.props.zoomButtonHidden) {
      this.setState({
        scale: MIN_SCALE,
        lockTranslate: { x: 0, y: 0 },
      }, () => {
        this.container.scrollLeft = 0;
        this.container.scrollTop = 0;
      });
    }
  }

  removeEventListeners () {
    this.removers.forEach(listeners => listeners());
    this.removers = [];
  }

  mouseWheelHandler = e => {
    e.preventDefault();

    const event = normalizeWheel(e);

    if (this.state.zoomMatrix.type === 'width') {
      // full width, scroll vertical
      this.container.scrollTop = Math.max(this.container.scrollTop + event.pixelY, this.state.lockScroll.y);
    } else {
      // full height, scroll horizontal
      this.container.scrollLeft = Math.max(this.container.scrollLeft + event.pixelY, this.state.lockScroll.x);
    }

    // lock horizontal scroll
    this.container.scrollLeft = Math.max(this.container.scrollLeft + event.pixelX, this.state.lockScroll.x);
  }

  mouseDownHandler = e => {
    this.container.style.cursor = 'grabbing';
    this.container.style.userSelect = 'none';

    this.setState({ dragPosition: {
      left: this.container.scrollLeft,
      top: this.container.scrollTop,
      // Get the current mouse position
      x: e.clientX,
      y: e.clientY,
    } });

    this.image.addEventListener('mousemove', this.mouseMoveHandler);
    this.image.addEventListener('mouseup', this.mouseUpHandler);
  }

  mouseMoveHandler = e => {
    const dx = e.clientX - this.state.dragPosition.x;
    const dy = e.clientY - this.state.dragPosition.y;

    this.container.scrollLeft = Math.max(this.state.dragPosition.left - dx, this.state.lockScroll.x);
    this.container.scrollTop = Math.max(this.state.dragPosition.top - dy, this.state.lockScroll.y);

    this.setState({ dragged: true });
  }

  mouseUpHandler = () => {
    this.container.style.cursor = 'grab';
    this.container.style.removeProperty('user-select');

    this.image.removeEventListener('mousemove', this.mouseMoveHandler);
    this.image.removeEventListener('mouseup', this.mouseUpHandler);
  }

  handleTouchStart = e => {
    if (e.touches.length !== 2) return;

    this.lastDistance = getDistance(...e.touches);
  }

  handleTouchMove = e => {
    const { scrollTop, scrollHeight, clientHeight } = this.container;
    if (e.touches.length === 1 && scrollTop !== scrollHeight - clientHeight) {
      // prevent propagating event to MediaModal
      e.stopPropagation();
      return;
    }
    if (e.touches.length !== 2) return;

    e.preventDefault();
    e.stopPropagation();

    const distance = getDistance(...e.touches);
    const midpoint = getMidpoint(...e.touches);
    const _MAX_SCALE = Math.max(MAX_SCALE, this.state.zoomMatrix.rate);
    const scale = clamp(MIN_SCALE, _MAX_SCALE, this.state.scale * distance / this.lastDistance);

    this.zoom(scale, midpoint);

    this.lastMidpoint = midpoint;
    this.lastDistance = distance;
  }

  zoom(nextScale, midpoint) {
    const { scale, zoomMatrix } = this.state;
    const { scrollLeft, scrollTop } = this.container;

    // math memo:
    // x = (scrollLeft + midpoint.x) / scrollWidth
    // x' = (nextScrollLeft + midpoint.x) / nextScrollWidth
    // scrollWidth = clientWidth * scale
    // scrollWidth' = clientWidth * nextScale
    // Solve x = x' for nextScrollLeft
    const nextScrollLeft = (scrollLeft + midpoint.x) * nextScale / scale - midpoint.x;
    const nextScrollTop = (scrollTop + midpoint.y) * nextScale / scale - midpoint.y;

    this.setState({ scale: nextScale }, () => {
      this.container.scrollLeft = nextScrollLeft;
      this.container.scrollTop = nextScrollTop;
      // reset the translateX/Y constantly
      if (nextScale < zoomMatrix.rate) {
        this.setState({
          lockTranslate: {
            x: zoomMatrix.fullScreen ? 0 : zoomMatrix.translateX * ((nextScale - MIN_SCALE) / (zoomMatrix.rate - MIN_SCALE)),
            y: zoomMatrix.fullScreen ? 0 : zoomMatrix.translateY * ((nextScale - MIN_SCALE) / (zoomMatrix.rate - MIN_SCALE)),
          },
        });
      }
    });
  }

  handleClick = e => {
    // don't propagate event to MediaModal
    e.stopPropagation();
    const dragged = this.state.dragged;
    this.setState({ dragged: false });
    if (dragged) return;
    const handler = this.props.onClick;
    if (handler) handler();
    this.setState({ navigationHidden: !this.state.navigationHidden });
  }

  handleMouseDown = e => {
    e.preventDefault();
  }

  initZoomMatrix = () => {
    const { width, height } = this.props;
    const { clientWidth, clientHeight } = this.container;
    const { offsetWidth, offsetHeight } = this.image;
    const clientHeightFixed = clientHeight - NAV_BAR_HEIGHT;

    const type = width / height < clientWidth / clientHeightFixed ? 'width' : 'height';
    const fullScreen = type === 'width' ?  width > clientWidth : height > clientHeightFixed;
    const rate = type === 'width' ? Math.min(clientWidth, width) / offsetWidth : Math.min(clientHeightFixed, height) / offsetHeight;
    const scrollTop = type === 'width' ?  (clientHeight - offsetHeight) / 2 - NAV_BAR_HEIGHT : (clientHeightFixed - offsetHeight) / 2;
    const scrollLeft = (clientWidth - offsetWidth) / 2;
    const translateX = type === 'width' ? (width - offsetWidth) / (2 * rate) : 0;
    const translateY = type === 'height' ? (height - offsetHeight) / (2 * rate) : 0;

    this.setState({
      zoomMatrix: {
        type: type,
        fullScreen: fullScreen,
        rate: rate,
        clientWidth: clientWidth,
        clientHeight: clientHeight,
        offsetWidth: offsetWidth,
        offsetHeight: offsetHeight,
        clientHeightFixed: clientHeightFixed,
        scrollTop: scrollTop,
        scrollLeft: scrollLeft,
        translateX: translateX,
        translateY: translateY,
      },
    });
  }

  handleZoomClick = e => {
    e.preventDefault();
    e.stopPropagation();

    const { scale, zoomMatrix } = this.state;

    if ( scale >= zoomMatrix.rate ) {
      this.setState({
        scale: MIN_SCALE,
        lockScroll: {
          x: 0,
          y: 0,
        },
        lockTranslate: {
          x: 0,
          y: 0,
        },
      }, () => {
        this.container.scrollLeft = 0;
        this.container.scrollTop = 0;
      });
    } else {
      this.setState({
        scale: zoomMatrix.rate,
        lockScroll: {
          x: zoomMatrix.scrollLeft,
          y: zoomMatrix.scrollTop,
        },
        lockTranslate: {
          x: zoomMatrix.fullScreen ? 0 : zoomMatrix.translateX,
          y: zoomMatrix.fullScreen ? 0 : zoomMatrix.translateY,
        },
      }, () => {
        this.container.scrollLeft = zoomMatrix.scrollLeft;
        this.container.scrollTop = zoomMatrix.scrollTop;
      });
    }

    this.container.style.cursor = 'grab';
    this.container.style.removeProperty('user-select');
  }

  setContainerRef = c => {
    this.container = c;
  }

  setImageRef = c => {
    this.image = c;
  }

  render () {
    const { alt, src, width, height, intl } = this.props;
    const { scale, lockTranslate } = this.state;
    const overflow = scale === MIN_SCALE ? 'hidden' : 'scroll';
    const zoomButtonShouldHide = this.state.navigationHidden || this.props.zoomButtonHidden || this.state.zoomMatrix.rate <= MIN_SCALE ? 'media-modal__zoom-button--hidden' : '';
    const zoomButtonTitle = this.state.zoomState === 'compress' ? intl.formatMessage(messages.compress) : intl.formatMessage(messages.expand);

    return (
      <React.Fragment>
        <IconButton
          className={`media-modal__zoom-button ${zoomButtonShouldHide}`}
          title={zoomButtonTitle}
          icon={this.state.zoomState}
          onClick={this.handleZoomClick}
          size={40}
          style={{
            fontSize: '30px', /* Fontawesome's fa-compress fa-expand is larger than fa-close */
          }}
        />
        <div
          className='zoomable-image'
          ref={this.setContainerRef}
          style={{ overflow }}
        >
          <img
            role='presentation'
            ref={this.setImageRef}
            alt={alt}
            title={alt}
            src={src}
            width={width}
            height={height}
            style={{
              transform: `scale(${scale}) translate(-${lockTranslate.x}px, -${lockTranslate.y}px)`,
              transformOrigin: '0 0',
            }}
            draggable={false}
            onClick={this.handleClick}
            onMouseDown={this.handleMouseDown}
          />
        </div>
      </React.Fragment>
    );
  }

}
