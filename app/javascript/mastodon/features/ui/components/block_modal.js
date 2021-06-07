import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { injectIntl, FormattedMessage } from 'react-intl';
import { makeGetAccount } from '../../../selectors';
import Button from '../../../components/button';
import { closeModal } from '../../../actions/modal';
import { blockAccount } from '../../../actions/accounts';
import { initReport } from '../../../actions/reports';


const makeMapStateToProps = () => {
  const getAccount = makeGetAccount();

  const mapStateToProps = state => ({
    account: getAccount(state, state.getIn(['blocks', 'new', 'account_id'])),
  });

  return mapStateToProps;
};

const mapDispatchToProps = dispatch => {
  return {
    onConfirm(account) {
      dispatch(blockAccount(account.get('id')));
    },

    onBlockAndReport(account) {
      dispatch(blockAccount(account.get('id')));
      dispatch(initReport(account));
    },

    onClose() {
      dispatch(closeModal());
    },
  };
};

@connect(makeMapStateToProps, mapDispatchToProps)
@injectIntl
export default class BlockModal extends React.PureComponent {

  static propTypes = {
    account: PropTypes.object.isRequired,
    onClose: PropTypes.func.isRequired,
    onBlockAndReport: PropTypes.func.isRequired,
    onConfirm: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  componentDidMount() {
    this.button.focus();
  }

  handleClick = () => {
    this.props.onClose();
    this.props.onConfirm(this.props.account);
  }

  handleSecondary = () => {
    this.props.onClose();
    this.props.onBlockAndReport(this.props.account);
  }

  handleCancel = () => {
    this.props.onClose();
  }

  setRef = (c) => {
    this.button = c;
  }

  render () {
    const { account } = this.props;

    return (
      <div className='modal-root__modal block-modal'>
        <div className='block-modal__container'>
          <p>
            <FormattedMessage
              id='confirmations.block.message'
              defaultMessage='Are you sure you want to block {name}?'
              values={{ name: <strong>@{account.get('acct')}</strong> }}
            />
          </p>
        </div>

        <div className='block-modal__action-bar'>
          <Button onClick={this.handleCancel} className='block-modal__cancel-button'>
            <FormattedMessage id='confirmation_modal.cancel' defaultMessage='Cancel' />
          </Button>
          <Button onClick={this.handleSecondary} className='confirmation-modal__secondary-button'>
            <FormattedMessage id='confirmations.block.block_and_report' defaultMessage='Block & Report' />
          </Button>
          <Button onClick={this.handleClick} ref={this.setRef}>
            <FormattedMessage id='confirmations.block.confirm' defaultMessage='Block' />
          </Button>
        </div>
      </div>
    );
  }

}
