import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import Toggle from 'react-toggle';
import AsyncSelect from 'react-select/async';
import { NonceProvider } from 'react-select';
import SettingToggle from '../../notifications/components/setting_toggle';

const messages = defineMessages({
  placeholder: { id: 'hashtag.column_settings.select.placeholder', defaultMessage: 'Enter hashtags…' },
  noOptions: { id: 'hashtag.column_settings.select.no_options_message', defaultMessage: 'No suggestions found' },
});

@injectIntl
export default class ColumnSettings extends React.PureComponent {

  static propTypes = {
    settings: ImmutablePropTypes.map.isRequired,
    onChange: PropTypes.func.isRequired,
    onLoad: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  state = {
    open: this.hasTags(),
  };

  hasTags () {
    return ['all', 'any', 'none'].map(mode => this.tags(mode).length > 0).includes(true);
  }

  tags (mode) {
    let tags = this.props.settings.getIn(['tags', mode]) || [];

    if (tags.toJSON) {
      return tags.toJSON();
    } else {
      return tags;
    }
  };

  onSelect = mode => value => this.props.onChange(['tags', mode], value);

  onToggle = () => {
    if (this.state.open && this.hasTags()) {
      this.props.onChange('tags', {});
    }

    this.setState({ open: !this.state.open });
  };

  noOptionsMessage = () => this.props.intl.formatMessage(messages.noOptions);

  modeSelect (mode) {
    return (
      <div className='column-settings__row'>
        <span className='column-settings__section'>
          {this.modeLabel(mode)}
        </span>

        <NonceProvider nonce={document.querySelector('meta[name=style-nonce]').content} cacheKey='tags'>
          <AsyncSelect
            isMulti
            autoFocus
            value={this.tags(mode)}
            onChange={this.onSelect(mode)}
            loadOptions={this.props.onLoad}
            className='column-select__container'
            classNamePrefix='column-select'
            name='tags'
            placeholder={this.props.intl.formatMessage(messages.placeholder)}
            noOptionsMessage={this.noOptionsMessage}
          />
        </NonceProvider>
      </div>
    );
  }

  modeLabel (mode) {
    switch(mode) {
    case 'any':
      return <FormattedMessage id='hashtag.column_settings.tag_mode.any' defaultMessage='Any of these' />;
    case 'all':
      return <FormattedMessage id='hashtag.column_settings.tag_mode.all' defaultMessage='All of these' />;
    case 'none':
      return <FormattedMessage id='hashtag.column_settings.tag_mode.none' defaultMessage='None of these' />;
    default:
      return '';
    }
  };

  render () {
    const { settings, onChange } = this.props;

    return (
      <div>
        <div className='column-settings__row'>
          <div className='setting-toggle'>
            <Toggle id='hashtag.column_settings.tag_toggle' onChange={this.onToggle} checked={this.state.open} />

            <span className='setting-toggle__label'>
              <FormattedMessage id='hashtag.column_settings.tag_toggle' defaultMessage='Include additional tags in this column' />
            </span>
          </div>
        </div>

        {this.state.open && (
          <div className='column-settings__hashtags'>
            {this.modeSelect('any')}
            {this.modeSelect('all')}
            {this.modeSelect('none')}
          </div>
        )}

        <div className='column-settings__row'>
          <SettingToggle settings={settings} settingPath={['local']} onChange={onChange} label={<FormattedMessage id='community.column_settings.local_only' defaultMessage='Local only' />} />
        </div>
      </div>
    );
  }

}
