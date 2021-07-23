import { connect } from 'react-redux';
import FederationDropdown from '../components/federation_dropdown';
import { changeComposeFederation } from '../../../actions/compose';
import { openModal, closeModal } from '../../../actions/modal';
import { isUserTouching } from '../../../is_mobile';

const mapStateToProps = state => ({
  isModalOpen: state.get('modal').modalType === 'ACTIONS',
  value: state.getIn(['compose', 'federation']),
});

const mapDispatchToProps = dispatch => ({

  onChange (value) {
    dispatch(changeComposeFederation(value));
  },

  isUserTouching,
  onModalOpen: props => dispatch(openModal('ACTIONS', props)),
  onModalClose: () => dispatch(closeModal()),

});

export default connect(mapStateToProps, mapDispatchToProps)(FederationDropdown);
