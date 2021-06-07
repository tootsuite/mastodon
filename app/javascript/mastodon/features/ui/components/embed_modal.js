import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { defineMessages, FormattedMessage, injectIntl } from 'react-intl';
import api from 'mastodon/api';
import IconButton from 'mastodon/components/icon_button';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
});

@injectIntl
export default class EmbedModal extends ImmutablePureComponent {

  static propTypes = {
    url: PropTypes.string.isRequired,
    onClose: PropTypes.func.isRequired,
    onError: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  }

  state = {
    loading: false,
    oembed: null,
  };

  componentDidMount () {
    const { url } = this.props;

    this.setState({ loading: true });

    api().post('/api/web/embed', { url }).then(res => {
      this.setState({ loading: false, oembed: res.data });

      const iframeDocument = this.iframe.contentWindow.document;

      iframeDocument.open();
      iframeDocument.write(res.data.html);
      iframeDocument.close();

      iframeDocument.body.style.margin = 0;
      this.iframe.width  = iframeDocument.body.scrollWidth;
      this.iframe.height = iframeDocument.body.scrollHeight;
    }).catch(error => {
      this.props.onError(error);
    });
  }

  setIframeRef = c =>  {
    this.iframe = c;
  }

  handleTextareaClick = (e) => {
    e.target.select();
  }

  render () {
    const { intl, onClose } = this.props;
    const { oembed } = this.state;

    return (
      <div className='modal-root__modal report-modal embed-modal'>
        <div className='report-modal__target'>
          <IconButton className='media-modal__close' title={intl.formatMessage(messages.close)} icon='times' onClick={onClose} size={16} />
          <FormattedMessage id='status.embed' defaultMessage='Embed' />
        </div>

        <div className='report-modal__container embed-modal__container' style={{ display: 'block' }}>
          <p className='hint'>
            <FormattedMessage id='embed.instructions' defaultMessage='Embed this status on your website by copying the code below.' />
          </p>

          <input
            type='text'
            className='embed-modal__html'
            readOnly
            value={oembed && oembed.html || ''}
            onClick={this.handleTextareaClick}
          />

          <p className='hint'>
            <FormattedMessage id='embed.preview' defaultMessage='Here is what it will look like:' />
          </p>

          <iframe
            className='embed-modal__iframe'
            frameBorder='0'
            ref={this.setIframeRef}
            sandbox='allow-same-origin'
            title='preview'
          />
        </div>
      </div>
    );
  }

}
