import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { connect } from 'react-redux';
import classNames from 'classnames';
import { changeUploadCompose, uploadThumbnail, onChangeMediaDescription, onChangeMediaFocus } from '../../../actions/compose';
import { getPointerPosition } from '../../video';
import { FormattedMessage, defineMessages, injectIntl } from 'react-intl';
import IconButton from 'mastodon/components/icon_button';
import Button from 'mastodon/components/button';
import Video from 'mastodon/features/video';
import Audio from 'mastodon/features/audio';
import Textarea from 'react-textarea-autosize';
import UploadProgress from 'mastodon/features/compose/components/upload_progress';
import CharacterCounter from 'mastodon/features/compose/components/character_counter';
import { length } from 'stringz';
import { Tesseract as fetchTesseract } from 'mastodon/features/ui/util/async-components';
import GIFV from 'mastodon/components/gifv';
import { me } from 'mastodon/initial_state';
// eslint-disable-next-line import/no-extraneous-dependencies
import tesseractCorePath from 'tesseract.js-core/tesseract-core.wasm.js';
// eslint-disable-next-line import/extensions
import tesseractWorkerPath from 'tesseract.js/dist/worker.min.js';
import { assetHost } from 'mastodon/utils/config';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
  apply: { id: 'upload_modal.apply', defaultMessage: 'Apply' },
  applying: { id: 'upload_modal.applying', defaultMessage: 'Applying…' },
  placeholder: { id: 'upload_modal.description_placeholder', defaultMessage: 'A quick brown fox jumps over the lazy dog' },
  chooseImage: { id: 'upload_modal.choose_image', defaultMessage: 'Choose image' },
  discardMessage: { id: 'confirmations.discard_edit_media.message', defaultMessage: 'You have unsaved changes to the media description or preview, discard them anyway?' },
  discardConfirm: { id: 'confirmations.discard_edit_media.confirm', defaultMessage: 'Discard' },
});

const mapStateToProps = (state, { id }) => ({
  media: state.getIn(['compose', 'media_attachments']).find(item => item.get('id') === id),
  account: state.getIn(['accounts', me]),
  isUploadingThumbnail: state.getIn(['compose', 'isUploadingThumbnail']),
  description: state.getIn(['compose', 'media_modal', 'description']),
  focusX: state.getIn(['compose', 'media_modal', 'focusX']),
  focusY: state.getIn(['compose', 'media_modal', 'focusY']),
  dirty: state.getIn(['compose', 'media_modal', 'dirty']),
  is_changing_upload: state.getIn(['compose', 'is_changing_upload']),
});

const mapDispatchToProps = (dispatch, { id }) => ({

  onSave: (description, x, y) => {
    dispatch(changeUploadCompose(id, { description, focus: `${x.toFixed(2)},${y.toFixed(2)}` }));
  },

  onChangeDescription: (description) => {
    dispatch(onChangeMediaDescription(description));
  },

  onChangeFocus: (focusX, focusY) => {
    dispatch(onChangeMediaFocus(focusX, focusY));
  },

  onSelectThumbnail: files => {
    dispatch(uploadThumbnail(id, files[0]));
  },

});

const removeExtraLineBreaks = str => str.replace(/\n\n/g, '******')
  .replace(/\n/g, ' ')
  .replace(/\*\*\*\*\*\*/g, '\n\n');

class ImageLoader extends React.PureComponent {

  static propTypes = {
    src: PropTypes.string.isRequired,
    width: PropTypes.number,
    height: PropTypes.number,
  };

  state = {
    loading: true,
  };

  componentDidMount() {
    const image = new Image();
    image.addEventListener('load', () => this.setState({ loading: false }));
    image.src = this.props.src;
  }

  render () {
    const { loading } = this.state;

    if (loading) {
      return <canvas width={this.props.width} height={this.props.height} />;
    } else {
      return <img {...this.props} alt='' />;
    }
  }

}

export default @connect(mapStateToProps, mapDispatchToProps, null, { forwardRef: true })
@(component => injectIntl(component, { withRef: true }))
class FocalPointModal extends ImmutablePureComponent {

  static propTypes = {
    media: ImmutablePropTypes.map.isRequired,
    account: ImmutablePropTypes.map.isRequired,
    isUploadingThumbnail: PropTypes.bool,
    onSave: PropTypes.func.isRequired,
    onChangeDescription: PropTypes.func.isRequired,
    onChangeFocus: PropTypes.func.isRequired,
    onSelectThumbnail: PropTypes.func.isRequired,
    onClose: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  state = {
    dragging: false,
    dirty: false,
    progress: 0,
    loading: true,
    ocrStatus: '',
  };

  componentWillUnmount () {
    document.removeEventListener('mousemove', this.handleMouseMove);
    document.removeEventListener('mouseup', this.handleMouseUp);
  }

  handleMouseDown = e => {
    document.addEventListener('mousemove', this.handleMouseMove);
    document.addEventListener('mouseup', this.handleMouseUp);

    this.updatePosition(e);
    this.setState({ dragging: true });
  }

  handleTouchStart = e => {
    document.addEventListener('touchmove', this.handleMouseMove);
    document.addEventListener('touchend', this.handleTouchEnd);

    this.updatePosition(e);
    this.setState({ dragging: true });
  }

  handleMouseMove = e => {
    this.updatePosition(e);
  }

  handleMouseUp = () => {
    document.removeEventListener('mousemove', this.handleMouseMove);
    document.removeEventListener('mouseup', this.handleMouseUp);

    this.setState({ dragging: false });
  }

  handleTouchEnd = () => {
    document.removeEventListener('touchmove', this.handleMouseMove);
    document.removeEventListener('touchend', this.handleTouchEnd);

    this.setState({ dragging: false });
  }

  updatePosition = e => {
    const { x, y } = getPointerPosition(this.node, e);
    const focusX   = (x - .5) *  2;
    const focusY   = (y - .5) * -2;

    this.props.onChangeFocus(focusX, focusY);
  }

  handleChange = e => {
    this.props.onChangeDescription(e.target.value);
  }

  handleKeyDown = (e) => {
    if (e.keyCode === 13 && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      e.stopPropagation();
      this.props.onChangeDescription(e.target.value);
      this.handleSubmit();
    }
  }

  handleSubmit = () => {
    this.props.onSave(this.props.description, this.props.focusX, this.props.focusY);
  }

  getCloseConfirmationMessage = () => {
    const { intl, dirty } = this.props;

    if (dirty) {
      return {
        message: intl.formatMessage(messages.discardMessage),
        confirm: intl.formatMessage(messages.discardConfirm),
      };
    } else {
      return null;
    }
  }

  setRef = c => {
    this.node = c;
  }

  handleTextDetection = () => {
    this._detectText();
  }

  _detectText = (refreshCache = false) => {
    const { media } = this.props;

    this.setState({ detecting: true });

    fetchTesseract().then(({ createWorker }) => {
      const worker = createWorker({
        workerPath: tesseractWorkerPath,
        corePath: tesseractCorePath,
        langPath: `${assetHost}/ocr/lang-data/`,
        logger: ({ status, progress }) => {
          if (status === 'recognizing text') {
            this.setState({ ocrStatus: 'detecting', progress });
          } else {
            this.setState({ ocrStatus: 'preparing', progress });
          }
        },
        cacheMethod: refreshCache ? 'refresh' : 'write',
      });

      let media_url = media.get('url');

      if (window.URL && URL.createObjectURL) {
        try {
          media_url = URL.createObjectURL(media.get('file'));
        } catch (error) {
          console.error(error);
        }
      }

      return (async () => {
        await worker.load();
        await worker.loadLanguage('eng');
        await worker.initialize('eng');
        const { data: { text } } = await worker.recognize(media_url);
        this.setState({ detecting: false });
        this.props.onChangeDescription(removeExtraLineBreaks(text));
        await worker.terminate();
      })().catch((e) => {
        if (refreshCache) {
          throw e;
        } else {
          this._detectText(true);
        }
      });
    }).catch((e) => {
      console.error(e);
      this.setState({ detecting: false });
    });
  }

  handleThumbnailChange = e => {
    if (e.target.files.length > 0) {
      this.props.onSelectThumbnail(e.target.files);
    }
  }

  setFileInputRef = c => {
    this.fileInput = c;
  }

  handleFileInputClick = () => {
    this.fileInput.click();
  }

  render () {
    const { media, intl, account, onClose, isUploadingThumbnail, description, focusX, focusY, dirty, is_changing_upload } = this.props;
    const { dragging, detecting, progress, ocrStatus } = this.state;
    const x = (focusX /  2) + .5;
    const y = (focusY / -2) + .5;

    const width  = media.getIn(['meta', 'original', 'width']) || null;
    const height = media.getIn(['meta', 'original', 'height']) || null;
    const focals = ['image', 'gifv'].includes(media.get('type'));
    const thumbnailable = ['audio', 'video'].includes(media.get('type'));

    const previewRatio  = 16/9;
    const previewWidth  = 200;
    const previewHeight = previewWidth / previewRatio;

    let descriptionLabel = null;

    if (media.get('type') === 'audio') {
      descriptionLabel = <FormattedMessage id='upload_form.audio_description' defaultMessage='Describe for people with hearing loss' />;
    } else if (media.get('type') === 'video') {
      descriptionLabel = <FormattedMessage id='upload_form.video_description' defaultMessage='Describe for people with hearing loss or visual impairment' />;
    } else {
      descriptionLabel = <FormattedMessage id='upload_form.description' defaultMessage='Describe for the visually impaired' />;
    }

    let ocrMessage = '';
    if (ocrStatus === 'detecting') {
      ocrMessage = <FormattedMessage id='upload_modal.analyzing_picture' defaultMessage='Analyzing picture…' />;
    } else {
      ocrMessage = <FormattedMessage id='upload_modal.preparing_ocr' defaultMessage='Preparing OCR…' />;
    }

    return (
      <div className='modal-root__modal report-modal' style={{ maxWidth: 960 }}>
        <div className='report-modal__target'>
          <IconButton className='report-modal__close' title={intl.formatMessage(messages.close)} icon='times' onClick={onClose} size={20} />
          <FormattedMessage id='upload_modal.edit_media' defaultMessage='Edit media' />
        </div>

        <div className='report-modal__container'>
          <div className='report-modal__comment'>
            {focals && <p><FormattedMessage id='upload_modal.hint' defaultMessage='Click or drag the circle on the preview to choose the focal point which will always be in view on all thumbnails.' /></p>}

            {thumbnailable && (
              <React.Fragment>
                <label className='setting-text-label' htmlFor='upload-modal__thumbnail'><FormattedMessage id='upload_form.thumbnail' defaultMessage='Change thumbnail' /></label>

                <Button disabled={isUploadingThumbnail} text={intl.formatMessage(messages.chooseImage)} onClick={this.handleFileInputClick} />

                <label>
                  <span style={{ display: 'none' }}>{intl.formatMessage(messages.chooseImage)}</span>

                  <input
                    id='upload-modal__thumbnail'
                    ref={this.setFileInputRef}
                    type='file'
                    accept='image/png,image/jpeg'
                    onChange={this.handleThumbnailChange}
                    style={{ display: 'none' }}
                    disabled={isUploadingThumbnail || is_changing_upload}
                  />
                </label>

                <hr className='setting-divider' />
              </React.Fragment>
            )}

            <label className='setting-text-label' htmlFor='upload-modal__description'>
              {descriptionLabel}
            </label>

            <div className='setting-text__wrapper'>
              <Textarea
                id='upload-modal__description'
                className='setting-text light'
                value={detecting ? '…' : description}
                onChange={this.handleChange}
                onKeyDown={this.handleKeyDown}
                disabled={detecting || is_changing_upload}
                autoFocus
              />

              <div className='setting-text__modifiers'>
                <UploadProgress progress={progress * 100} active={detecting} icon='file-text-o' message={ocrMessage} />
              </div>
            </div>

            <div className='setting-text__toolbar'>
              <button disabled={detecting || media.get('type') !== 'image' || is_changing_upload} className='link-button' onClick={this.handleTextDetection}><FormattedMessage id='upload_modal.detect_text' defaultMessage='Detect text from picture' /></button>
              <CharacterCounter max={1500} text={detecting ? '' : description} />
            </div>

            <Button disabled={!dirty || detecting || isUploadingThumbnail || length(description) > 1500 || is_changing_upload} text={intl.formatMessage(is_changing_upload ? messages.applying : messages.apply)} onClick={this.handleSubmit} />
          </div>

          <div className='focal-point-modal__content'>
            {focals && (
              <div className={classNames('focal-point', { dragging })} ref={this.setRef} onMouseDown={this.handleMouseDown} onTouchStart={this.handleTouchStart}>
                {media.get('type') === 'image' && <ImageLoader src={media.get('url')} width={width} height={height} alt='' />}
                {media.get('type') === 'gifv' && <GIFV src={media.get('url')} width={width} height={height} />}

                <div className='focal-point__preview'>
                  <strong><FormattedMessage id='upload_modal.preview_label' defaultMessage='Preview ({ratio})' values={{ ratio: '16:9' }} /></strong>
                  <div style={{ width: previewWidth, height: previewHeight, backgroundImage: `url(${media.get('preview_url')})`, backgroundSize: 'cover', backgroundPosition: `${x * 100}% ${y * 100}%` }} />
                </div>

                <div className='focal-point__reticle' style={{ top: `${y * 100}%`, left: `${x * 100}%` }} />
                <div className='focal-point__overlay' />
              </div>
            )}

            {media.get('type') === 'video' && (
              <Video
                preview={media.get('preview_url')}
                frameRate={media.getIn(['meta', 'original', 'frame_rate'])}
                blurhash={media.get('blurhash')}
                src={media.get('url')}
                detailed
                inline
                editable
              />
            )}

            {media.get('type') === 'audio' && (
              <Audio
                src={media.get('url')}
                duration={media.getIn(['meta', 'original', 'duration'], 0)}
                height={150}
                poster={media.get('preview_url') || account.get('avatar_static')}
                backgroundColor={media.getIn(['meta', 'colors', 'background'])}
                foregroundColor={media.getIn(['meta', 'colors', 'foreground'])}
                accentColor={media.getIn(['meta', 'colors', 'accent'])}
                editable
              />
            )}
          </div>
        </div>
      </div>
    );
  }

}
