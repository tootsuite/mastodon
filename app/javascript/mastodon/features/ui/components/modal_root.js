import React from 'react';
import PropTypes from 'prop-types';
import { getScrollbarWidth } from 'mastodon/utils/scrollbar';
import Base from 'mastodon/components/modal_root';
import BundleContainer from '../containers/bundle_container';
import BundleModalError from './bundle_modal_error';
import ModalLoading from './modal_loading';
import ActionsModal from './actions_modal';
import MediaModal from './media_modal';
import VideoModal from './video_modal';
import BoostModal from './boost_modal';
import AudioModal from './audio_modal';
import ConfirmationModal from './confirmation_modal';
import FocalPointModal from './focal_point_modal';
import {
  MuteModal,
  BlockModal,
  ReportModal,
  EmbedModal,
  ListEditor,
  ListAdder,
} from '../../../features/ui/util/async-components';

const MODAL_COMPONENTS = {
  'MEDIA': () => Promise.resolve({ default: MediaModal }),
  'VIDEO': () => Promise.resolve({ default: VideoModal }),
  'AUDIO': () => Promise.resolve({ default: AudioModal }),
  'BOOST': () => Promise.resolve({ default: BoostModal }),
  'CONFIRM': () => Promise.resolve({ default: ConfirmationModal }),
  'MUTE': MuteModal,
  'BLOCK': BlockModal,
  'REPORT': ReportModal,
  'ACTIONS': () => Promise.resolve({ default: ActionsModal }),
  'EMBED': EmbedModal,
  'LIST_EDITOR': ListEditor,
  'FOCAL_POINT': () => Promise.resolve({ default: FocalPointModal }),
  'LIST_ADDER':ListAdder,
};

export default class ModalRoot extends React.PureComponent {

  static propTypes = {
    type: PropTypes.string,
    props: PropTypes.object,
    onClose: PropTypes.func.isRequired,
  };

  state = {
    backgroundColor: null,
  };

  getSnapshotBeforeUpdate () {
    return { visible: !!this.props.type };
  }

  componentDidUpdate (prevProps, prevState, { visible }) {
    if (visible) {
      document.body.classList.add('with-modals--active');
      document.documentElement.style.marginRight = `${getScrollbarWidth()}px`;
    } else {
      document.body.classList.remove('with-modals--active');
      document.documentElement.style.marginRight = 0;
    }
  }

  setBackgroundColor = color => {
    this.setState({ backgroundColor: color });
  }

  renderLoading = modalId => () => {
    return ['MEDIA', 'VIDEO', 'BOOST', 'CONFIRM', 'ACTIONS'].indexOf(modalId) === -1 ? <ModalLoading /> : null;
  }

  renderError = (props) => {
    const { onClose } = this.props;

    return <BundleModalError {...props} onClose={onClose} />;
  }

  handleClose = () => {
    const { onClose } = this.props;
    let message = null;
    try {
      message = this._modal?.getWrappedInstance?.().getCloseConfirmationMessage?.();
    } catch (_) {
      // injectIntl defines `getWrappedInstance` but errors out if `withRef`
      // isn't set.
      // This would be much smoother with react-intl 3+ and `forwardRef`.
    }
    onClose(message);
  }

  setModalRef = (c) => {
    this._modal = c;
  }

  render () {
    const { type, props } = this.props;
    const { backgroundColor } = this.state;
    const visible = !!type;

    return (
      <Base backgroundColor={backgroundColor} onClose={this.handleClose}>
        {visible && (
          <BundleContainer fetchComponent={MODAL_COMPONENTS[type]} loading={this.renderLoading(type)} error={this.renderError} renderDelay={200}>
            {(SpecificComponent) => <SpecificComponent {...props} onChangeBackgroundColor={this.setBackgroundColor} onClose={this.handleClose} ref={this.setModalRef} />}
          </BundleContainer>
        )}
      </Base>
    );
  }

}
