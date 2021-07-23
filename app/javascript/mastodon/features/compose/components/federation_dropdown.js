import React from 'react';
import PropTypes from 'prop-types';
import { injectIntl, defineMessages } from 'react-intl';
import IconButton from '../../../components/icon_button';
import Overlay from 'react-overlays/lib/Overlay';
import Motion from '../../ui/util/optional_motion';
import spring from 'react-motion/lib/spring';
import { supportsPassiveEvents } from 'detect-passive-events';
import classNames from 'classnames';

const messages = defineMessages({
  federate_short: { id: 'federation.federated.short', defaultMessage: 'Federated' },
  federate_long: { id: 'federation.federated.long', defaultMessage: 'Allow toot to reach other instances' },
  local_only_short: { id: 'federation.local_only.short', defaultMessage: 'Local-only' },
  local_only_long: { id: 'federation.local_only.long', defaultMessage: 'Restrict this toot only to my instance' },
  change_federation: { id: 'federation.change', defaultMessage: 'Adjust status federation' },
});

const listenerOptions = supportsPassiveEvents ? { passive: true } : false;

class FederationDropdownMenu extends React.PureComponent {

  static propTypes = {
    style: PropTypes.object,
    items: PropTypes.array.isRequired,
    value: PropTypes.bool.isRequired,
    onClose: PropTypes.func.isRequired,
    onChange: PropTypes.func.isRequired,
  };

  state = {
    mounted: false,
  };

  handleDocumentClick = e => {
    if (this.node && !this.node.contains(e.target)) {
      this.props.onClose();
    }
  }

  handleKeyDown = e => {
    const { items } = this.props;
    const value = Boolean(e.currentTarget.getAttribute('data-index'));
    const index = items.findIndex(item => {
      return (item.value === value);
    });
    let element;

    switch(e.key) {
    case 'Escape':
      this.props.onClose();
      break;
    case 'Enter':
      this.handleClick(e);
      break;
    case 'ArrowDown':
      element = this.node.childNodes[index + 1];
      if (element) {
        element.focus();
        this.props.onChange(Boolean(element.getAttribute('data-index')));
      }
      break;
    case 'ArrowUp':
      element = this.node.childNodes[index - 1];
      if (element) {
        element.focus();
        this.props.onChange(Boolean(element.getAttribute('data-index')));
      }
      break;
    case 'Home':
      element = this.node.firstChild;
      if (element) {
        element.focus();
        this.props.onChange(Boolean(element.getAttribute('data-index')));
      }
      break;
    case 'End':
      element = this.node.lastChild;
      if (element) {
        element.focus();
        this.props.onChange(Boolean(element.getAttribute('data-index')));
      }
      break;
    }
  }

  handleClick = e => {
    const value = Boolean(e.currentTarget.getAttribute('data-index'));

    e.preventDefault();

    this.props.onClose();
    this.props.onChange(value);
  }

  componentDidMount () {
    document.addEventListener('click', this.handleDocumentClick, false);
    document.addEventListener('touchend', this.handleDocumentClick, listenerOptions);
    if (this.focusedItem) this.focusedItem.focus();
    this.setState({ mounted: true });
  }

  componentWillUnmount () {
    document.removeEventListener('click', this.handleDocumentClick, false);
    document.removeEventListener('touchend', this.handleDocumentClick, listenerOptions);
  }

  setRef = c => {
    this.node = c;
  }

  setFocusRef = c => {
    this.focusedItem = c;
  }

  render () {
    const { mounted } = this.state;
    const { style, items, value } = this.props;

    return (
      <Motion defaultStyle={{ opacity: 0, scaleX: 0.85, scaleY: 0.75 }} style={{ opacity: spring(1, { damping: 35, stiffness: 400 }), scaleX: spring(1, { damping: 35, stiffness: 400 }), scaleY: spring(1, { damping: 35, stiffness: 400 }) }}>
        {({ opacity, scaleX, scaleY }) => (
          // It should not be transformed when mounting because the resulting
          // size will be used to determine the coordinate of the menu by
          // react-overlays
          <div className='privacy-dropdown__dropdown' style={{ ...style, opacity: opacity, transform: mounted ? `scale(${scaleX}, ${scaleY})` : null }} role='listbox' ref={this.setRef}>
            {items.map(item => (
              <div role='option' tabIndex='0' key={item.value} data-index={item.value ? item.value : undefined} onKeyDown={this.handleKeyDown} onClick={this.handleClick} className={classNames('privacy-dropdown__option', { active: item.value === value })} aria-selected={item.value === value} ref={item.value === value ? this.setFocusRef : null}>
                <div className='privacy-dropdown__option__icon'>
                  <i className={`fa fa-fw fa-${item.icon}`} />
                </div>

                <div className='privacy-dropdown__option__content'>
                  <strong>{item.text}</strong>
                  {item.meta}
                </div>
              </div>
            ))}
          </div>
        )}
      </Motion>
    );
  }

}

@injectIntl
export default class FederationDropdown extends React.PureComponent {

  static propTypes = {
    isUserTouching: PropTypes.func,
    isModalOpen: PropTypes.bool.isRequired,
    onModalOpen: PropTypes.func,
    onModalClose: PropTypes.func,
    value: PropTypes.bool.isRequired,
    onChange: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  state = {
    open: false,
    placement: null,
  };

  handleToggle = ({ target }) => {
    if (this.props.isUserTouching()) {
      if (this.state.open) {
        this.props.onModalClose();
      } else {
        this.props.onModalOpen({
          actions: this.options.map(option => ({ ...option, active: option.value === this.props.value })),
          onClick: this.handleModalActionClick,
        });
      }
    } else {
      const { top } = target.getBoundingClientRect();
      this.setState({ placement: top * 2 < innerHeight ? 'bottom' : 'top' });
      this.setState({ open: !this.state.open });
    }
  }

  handleModalActionClick = (e) => {
    e.preventDefault();

    const { value } = this.options[e.currentTarget.getAttribute('data-index')];

    this.props.onModalClose();
    this.props.onChange(value);
  }

  handleKeyDown = e => {
    switch(e.key) {
    case 'Escape':
      this.handleClose();
      break;
    }
  }

  handleClose = () => {
    this.setState({ open: false });
  }

  handleChange = value => {
    this.props.onChange(value);
  }

  componentWillMount () {
    const { intl: { formatMessage } } = this.props;

    this.options = [
      { icon: 'link', value: true, text: formatMessage(messages.federate_short), meta: formatMessage(messages.federate_long) },
      { icon: 'chain-broken', value: false, text: formatMessage(messages.local_only_short), meta: formatMessage(messages.local_only_long) },
    ];
  }

  render () {
    const { value, intl } = this.props;
    const { open, placement } = this.state;

    const valueOption = this.options.find(item => item.value === value);

    return (
      <div className={classNames('privacy-dropdown', { active: open })} onKeyDown={this.handleKeyDown}>
        <div className={classNames('privacy-dropdown__value', { active: this.options.indexOf(valueOption) === 0 })}>
          <IconButton
            className='privacy-dropdown__value-icon'
            icon={valueOption.icon}
            title={intl.formatMessage(messages.change_federation)}
            size={18}
            expanded={open}
            active={open}
            inverted
            onClick={this.handleToggle}
            style={{ height: null, lineHeight: '27px' }}
          />
        </div>

        <Overlay show={open} placement={placement} target={this}>
          <FederationDropdownMenu
            items={this.options}
            value={value}
            onClose={this.handleClose}
            onChange={this.handleChange}
          />
        </Overlay>
      </div>
    );
  }

}
