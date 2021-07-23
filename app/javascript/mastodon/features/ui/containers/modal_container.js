import { connect } from 'react-redux';
import { openModal, closeModal } from '../../../actions/modal';
import ModalRoot from '../components/modal_root';

const mapStateToProps = state => ({
  type: state.getIn(['modal', 0, 'modalType'], null),
  props: state.getIn(['modal', 0, 'modalProps'], {}),
});

const mapDispatchToProps = dispatch => ({
  onClose (confirmationMessage) {
    if (confirmationMessage) {
      dispatch(
        openModal('CONFIRM', {
          message: confirmationMessage.message,
          confirm: confirmationMessage.confirm,
          onConfirm: () => dispatch(closeModal()),
        }),
      );
    } else {
      dispatch(closeModal());
    }
  },
});

export default connect(mapStateToProps, mapDispatchToProps)(ModalRoot);
