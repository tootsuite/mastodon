import React, { PureComponent } from 'react';
import { ScrollContainer } from 'react-router-scroll-4';
import PropTypes from 'prop-types';
import IntersectionObserverArticleContainer from '../containers/intersection_observer_article_container';
import LoadMore from './load_more';
import LoadPending from './load_pending';
import IntersectionObserverWrapper from '../features/ui/util/intersection_observer_wrapper';
import { throttle } from 'lodash';
import { List as ImmutableList } from 'immutable';
import classNames from 'classnames';
import { attachFullscreenListener, detachFullscreenListener, isFullscreen } from '../features/ui/util/fullscreen';
import LoadingIndicator from './loading_indicator';
import { connect } from 'react-redux';

const MOUSE_IDLE_DELAY = 300;

const mapStateToProps = (state, { scrollKey }) => {
  return {
    preventScroll: scrollKey === state.getIn(['dropdown_menu', 'scroll_key']),
  };
};

@connect(mapStateToProps, null, null, { forwardRef: true })
export default class ScrollableList extends PureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    scrollKey: PropTypes.string.isRequired,
    onLoadMore: PropTypes.func,
    onLoadPending: PropTypes.func,
    onScrollToTop: PropTypes.func,
    onScroll: PropTypes.func,
    trackScroll: PropTypes.bool,
    shouldUpdateScroll: PropTypes.func,
    isLoading: PropTypes.bool,
    showLoading: PropTypes.bool,
    hasMore: PropTypes.bool,
    numPending: PropTypes.number,
    prepend: PropTypes.node,
    append: PropTypes.node,
    alwaysPrepend: PropTypes.bool,
    emptyMessage: PropTypes.node,
    children: PropTypes.node,
    bindToDocument: PropTypes.bool,
    preventScroll: PropTypes.bool,
  };

  static defaultProps = {
    trackScroll: true,
  };

  state = {
    fullscreen: null,
    cachedMediaWidth: 250, // Default media/card width using default Mastodon theme
  };

  intersectionObserverWrapper = new IntersectionObserverWrapper();

  handleScroll = throttle(() => {
    if (this.node) {
      const scrollTop = this.getScrollTop();
      const scrollHeight = this.getScrollHeight();
      const clientHeight = this.getClientHeight();
      const offset = scrollHeight - scrollTop - clientHeight;

      if (400 > offset && this.props.onLoadMore && this.props.hasMore && !this.props.isLoading) {
        this.props.onLoadMore();
      }

      if (scrollTop < 100 && this.props.onScrollToTop) {
        this.props.onScrollToTop();
      } else if (this.props.onScroll) {
        this.props.onScroll();
      }

      if (!this.lastScrollWasSynthetic) {
        // If the last scroll wasn't caused by setScrollTop(), assume it was
        // intentional and cancel any pending scroll reset on mouse idle
        this.scrollToTopOnMouseIdle = false;
      }
      this.lastScrollWasSynthetic = false;
    }
  }, 150, {
    trailing: true,
  });

  mouseIdleTimer = null;
  mouseMovedRecently = false;
  lastScrollWasSynthetic = false;
  scrollToTopOnMouseIdle = false;

  _getScrollingElement = () => {
    if (this.props.bindToDocument) {
      return (document.scrollingElement || document.body);
    } else {
      return this.node;
    }
  }

  setScrollTop = newScrollTop => {
    if (this.getScrollTop() !== newScrollTop) {
      this.lastScrollWasSynthetic = true;

      this._getScrollingElement().scrollTop = newScrollTop;
    }
  };

  clearMouseIdleTimer = () => {
    if (this.mouseIdleTimer === null) {
      return;
    }

    clearTimeout(this.mouseIdleTimer);
    this.mouseIdleTimer = null;
  };

  handleMouseMove = throttle(() => {
    // As long as the mouse keeps moving, clear and restart the idle timer.
    this.clearMouseIdleTimer();
    this.mouseIdleTimer = setTimeout(this.handleMouseIdle, MOUSE_IDLE_DELAY);

    if (!this.mouseMovedRecently && this.getScrollTop() === 0) {
      // Only set if we just started moving and are scrolled to the top.
      this.scrollToTopOnMouseIdle = true;
    }

    // Save setting this flag for last, so we can do the comparison above.
    this.mouseMovedRecently = true;
  }, MOUSE_IDLE_DELAY / 2);

  handleWheel = throttle(() => {
    this.scrollToTopOnMouseIdle = false;
  }, 150, {
    trailing: true,
  });

  handleMouseIdle = () => {
    if (this.scrollToTopOnMouseIdle && !this.props.preventScroll) {
      this.setScrollTop(0);
    }

    this.mouseMovedRecently = false;
    this.scrollToTopOnMouseIdle = false;
  }

  componentDidMount () {
    this.attachScrollListener();
    this.attachIntersectionObserver();

    attachFullscreenListener(this.onFullScreenChange);

    // Handle initial scroll posiiton
    this.handleScroll();
  }

  getScrollPosition = () => {
    if (this.node && (this.getScrollTop() > 0 || this.mouseMovedRecently)) {
      return { height: this.getScrollHeight(), top: this.getScrollTop() };
    } else {
      return null;
    }
  }

  getScrollTop = () => {
    return this._getScrollingElement().scrollTop;
  }

  getScrollHeight = () => {
    return this._getScrollingElement().scrollHeight;
  }

  getClientHeight = () => {
    return this._getScrollingElement().clientHeight;
  }

  updateScrollBottom = (snapshot) => {
    const newScrollTop = this.getScrollHeight() - snapshot;

    this.setScrollTop(newScrollTop);
  }

  getSnapshotBeforeUpdate (prevProps) {
    const someItemInserted = React.Children.count(prevProps.children) > 0 &&
      React.Children.count(prevProps.children) < React.Children.count(this.props.children) &&
      this.getFirstChildKey(prevProps) !== this.getFirstChildKey(this.props);
    const pendingChanged = (prevProps.numPending > 0) !== (this.props.numPending > 0);

    if (pendingChanged || someItemInserted && (this.getScrollTop() > 0 || this.mouseMovedRecently || this.props.preventScroll)) {
      return this.getScrollHeight() - this.getScrollTop();
    } else {
      return null;
    }
  }

  componentDidUpdate (prevProps, prevState, snapshot) {
    // Reset the scroll position when a new child comes in in order not to
    // jerk the scrollbar around if you're already scrolled down the page.
    if (snapshot !== null) {
      this.setScrollTop(this.getScrollHeight() - snapshot);
    }
  }

  cacheMediaWidth = (width) => {
    if (width && this.state.cachedMediaWidth !== width) {
      this.setState({ cachedMediaWidth: width });
    }
  }

  componentWillUnmount () {
    this.clearMouseIdleTimer();
    this.detachScrollListener();
    this.detachIntersectionObserver();

    detachFullscreenListener(this.onFullScreenChange);
  }

  onFullScreenChange = () => {
    this.setState({ fullscreen: isFullscreen() });
  }

  attachIntersectionObserver () {
    let nodeOptions = {
      root: this.node,
      rootMargin: '300% 0px',
    };

    this.intersectionObserverWrapper
      .connect(this.props.bindToDocument ? {} : nodeOptions);
  }

  detachIntersectionObserver () {
    this.intersectionObserverWrapper.disconnect();
  }

  attachScrollListener () {
    if (this.props.bindToDocument) {
      document.addEventListener('scroll', this.handleScroll);
      document.addEventListener('wheel', this.handleWheel);
    } else {
      this.node.addEventListener('scroll', this.handleScroll);
      this.node.addEventListener('wheel', this.handleWheel);
    }
  }

  detachScrollListener () {
    if (this.props.bindToDocument) {
      document.removeEventListener('scroll', this.handleScroll);
      document.removeEventListener('wheel', this.handleWheel);
    } else {
      this.node.removeEventListener('scroll', this.handleScroll);
      this.node.removeEventListener('wheel', this.handleWheel);
    }
  }

  getFirstChildKey (props) {
    const { children } = props;
    let firstChild     = children;

    if (children instanceof ImmutableList) {
      firstChild = children.get(0);
    } else if (Array.isArray(children)) {
      firstChild = children[0];
    }

    return firstChild && firstChild.key;
  }

  setRef = (c) => {
    this.node = c;
  }

  handleLoadMore = e => {
    e.preventDefault();
    this.props.onLoadMore();
  }

  handleLoadPending = e => {
    e.preventDefault();
    this.props.onLoadPending();
    // Prevent the weird scroll-jumping behavior, as we explicitly don't want to
    // scroll to top, and we know the scroll height is going to change
    this.scrollToTopOnMouseIdle = false;
    this.lastScrollWasSynthetic = false;
    this.clearMouseIdleTimer();
    this.mouseIdleTimer = setTimeout(this.handleMouseIdle, MOUSE_IDLE_DELAY);
    this.mouseMovedRecently = true;
  }

  render () {
    const { children, scrollKey, trackScroll, shouldUpdateScroll, showLoading, isLoading, hasMore, numPending, prepend, alwaysPrepend, append, emptyMessage, onLoadMore } = this.props;
    const { fullscreen } = this.state;
    const childrenCount = React.Children.count(children);

    const loadMore     = (hasMore && onLoadMore) ? <LoadMore visible={!isLoading} onClick={this.handleLoadMore} /> : null;
    const loadPending  = (numPending > 0) ? <LoadPending count={numPending} onClick={this.handleLoadPending} /> : null;
    let scrollableArea = null;

    if (showLoading) {
      scrollableArea = (
        <div className='scrollable scrollable--flex' ref={this.setRef}>
          <div role='feed' className='item-list'>
            {prepend}
          </div>

          <div className='scrollable__append'>
            <LoadingIndicator />
          </div>
        </div>
      );
    } else if (isLoading || childrenCount > 0 || numPending > 0 || hasMore || !emptyMessage) {
      scrollableArea = (
        <div className={classNames('scrollable', { fullscreen })} ref={this.setRef} onMouseMove={this.handleMouseMove}>
          <div role='feed' className='item-list'>
            {prepend}

            {loadPending}

            {React.Children.map(this.props.children, (child, index) => (
              <IntersectionObserverArticleContainer
                key={child.key}
                id={child.key}
                index={index}
                listLength={childrenCount}
                intersectionObserverWrapper={this.intersectionObserverWrapper}
                saveHeightKey={trackScroll ? `${this.context.router.route.location.key}:${scrollKey}` : null}
              >
                {React.cloneElement(child, {
                  getScrollPosition: this.getScrollPosition,
                  updateScrollBottom: this.updateScrollBottom,
                  cachedMediaWidth: this.state.cachedMediaWidth,
                  cacheMediaWidth: this.cacheMediaWidth,
                })}
              </IntersectionObserverArticleContainer>
            ))}

            {loadMore}

            {!hasMore && append}
          </div>
        </div>
      );
    } else {
      scrollableArea = (
        <div className={classNames('scrollable scrollable--flex', { fullscreen })} ref={this.setRef}>
          {alwaysPrepend && prepend}

          <div className='empty-column-indicator'>
            {emptyMessage}
          </div>
        </div>
      );
    }

    if (trackScroll) {
      return (
        <ScrollContainer scrollKey={scrollKey} shouldUpdateScroll={shouldUpdateScroll}>
          {scrollableArea}
        </ScrollContainer>
      );
    } else {
      return scrollableArea;
    }
  }

}
