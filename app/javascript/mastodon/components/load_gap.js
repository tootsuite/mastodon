import React from 'react';
import PropTypes from 'prop-types';
import { injectIntl, defineMessages } from 'react-intl';
import Icon from 'mastodon/components/icon';

const messages = defineMessages({
  load_more: { id: 'status.load_more', defaultMessage: 'Load more' },
});

@injectIntl
export default class LoadGap extends React.PureComponent {

  static propTypes = {
    disabled: PropTypes.bool,
    maxId: PropTypes.string,
    onClick: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleClick = () => {
    this.props.onClick(this.props.maxId);
  }

  render () {
    const { disabled, intl } = this.props;

    return (
      <button className='load-more load-gap' disabled={disabled} onClick={this.handleClick} aria-label={intl.formatMessage(messages.load_more)}>
        <Icon id='ellipsis-h' />
      </button>
    );
  }

}
