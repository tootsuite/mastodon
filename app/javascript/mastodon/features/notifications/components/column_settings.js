import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { FormattedMessage } from 'react-intl';
import ClearColumnButton from './clear_column_button';
import GrantPermissionButton from './grant_permission_button';
import SettingToggle from './setting_toggle';
import PillBarButton from './pill_bar_button';

export default class ColumnSettings extends React.PureComponent {

  static propTypes = {
    settings: ImmutablePropTypes.map.isRequired,
    pushSettings: ImmutablePropTypes.map.isRequired,
    onChange: PropTypes.func.isRequired,
    onClear: PropTypes.func.isRequired,
    onRequestNotificationPermission: PropTypes.func,
    alertsEnabled: PropTypes.bool,
    browserSupport: PropTypes.bool,
    browserPermission: PropTypes.bool,
  };

  onPushChange = (path, checked) => {
    this.props.onChange(['push', ...path], checked);
  }

  render () {
    const { settings, pushSettings, onChange, onClear, alertsEnabled, browserSupport, browserPermission, onRequestNotificationPermission } = this.props;

    const filterShowStr = <FormattedMessage id='notifications.column_settings.filter_bar.show' defaultMessage='Show' />;
    const filterAdvancedStr = <FormattedMessage id='notifications.column_settings.filter_bar.advanced' defaultMessage='Display all categories' />;
    const alertStr  = <FormattedMessage id='notifications.column_settings.alert' defaultMessage='Desktop notifications' />;
    const showStr   = <FormattedMessage id='notifications.column_settings.show' defaultMessage='Show in column' />;
    const soundStr  = <FormattedMessage id='notifications.column_settings.sound' defaultMessage='Play sound' />;

    const showPushSettings = pushSettings.get('browserSupport') && pushSettings.get('isSubscribed');
    const pushStr = showPushSettings && <FormattedMessage id='notifications.column_settings.push' defaultMessage='Push notifications' />;

    return (
      <div>
        {alertsEnabled && browserSupport && browserPermission === 'denied' && (
          <div className='column-settings__row column-settings__row--with-margin'>
            <span className='warning-hint'><FormattedMessage id='notifications.permission_denied' defaultMessage='Desktop notifications are unavailable due to previously denied browser permissions request' /></span>
          </div>
        )}

        {alertsEnabled && browserSupport && browserPermission === 'default' && (
          <div className='column-settings__row column-settings__row--with-margin'>
            <span className='warning-hint'>
              <FormattedMessage id='notifications.permission_required' defaultMessage='Desktop notifications are unavailable because the required permission has not been granted.' /> <GrantPermissionButton onClick={onRequestNotificationPermission} />
            </span>
          </div>
        )}

        <div className='column-settings__row'>
          <ClearColumnButton onClick={onClear} />
        </div>

        <div role='group' aria-labelledby='notifications-unread-markers'>
          <span id='notifications-unread-markers' className='column-settings__section'>
            <FormattedMessage id='notifications.column_settings.unread_markers.category' defaultMessage='Unread notification markers' />
          </span>

          <div className='column-settings__row'>
            <SettingToggle id='unread-notification-markers' prefix='notifications' settings={settings} settingPath={['showUnread']} onChange={onChange} label={filterShowStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-filter-bar'>
          <span id='notifications-filter-bar' className='column-settings__section'>
            <FormattedMessage id='notifications.column_settings.filter_bar.category' defaultMessage='Quick filter bar' />
          </span>

          <div className='column-settings__row'>
            <SettingToggle id='show-filter-bar' prefix='notifications' settings={settings} settingPath={['quickFilter', 'show']} onChange={onChange} label={filterShowStr} />
            <SettingToggle id='show-filter-bar' prefix='notifications' settings={settings} settingPath={['quickFilter', 'advanced']} onChange={onChange} label={filterAdvancedStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-follow'>
          <span id='notifications-follow' className='column-settings__section'><FormattedMessage id='notifications.column_settings.follow' defaultMessage='New followers:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'follow']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'follow']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'follow']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'follow']} onChange={onChange} label={soundStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-follow-request'>
          <span id='notifications-follow-request' className='column-settings__section'><FormattedMessage id='notifications.column_settings.follow_request' defaultMessage='New follow requests:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'follow_request']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'follow_request']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'follow_request']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'follow_request']} onChange={onChange} label={soundStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-favourite'>
          <span id='notifications-favourite' className='column-settings__section'><FormattedMessage id='notifications.column_settings.favourite' defaultMessage='Favourites:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'favourite']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'favourite']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'favourite']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'favourite']} onChange={onChange} label={soundStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-mention'>
          <span id='notifications-mention' className='column-settings__section'><FormattedMessage id='notifications.column_settings.mention' defaultMessage='Mentions:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'mention']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'mention']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'mention']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'mention']} onChange={onChange} label={soundStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-reblog'>
          <span id='notifications-reblog' className='column-settings__section'><FormattedMessage id='notifications.column_settings.reblog' defaultMessage='Boosts:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'reblog']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'reblog']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'reblog']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'reblog']} onChange={onChange} label={soundStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-poll'>
          <span id='notifications-poll' className='column-settings__section'><FormattedMessage id='notifications.column_settings.poll' defaultMessage='Poll results:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'poll']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'poll']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'poll']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'poll']} onChange={onChange} label={soundStr} />
          </div>
        </div>

        <div role='group' aria-labelledby='notifications-status'>
          <span id='notifications-status' className='column-settings__section'><FormattedMessage id='notifications.column_settings.status' defaultMessage='New toots:' /></span>

          <div className='column-settings__pillbar'>
            <PillBarButton disabled={browserPermission === 'denied'} prefix='notifications_desktop' settings={settings} settingPath={['alerts', 'status']} onChange={onChange} label={alertStr} />
            {showPushSettings && <PillBarButton prefix='notifications_push' settings={pushSettings} settingPath={['alerts', 'status']} onChange={this.onPushChange} label={pushStr} />}
            <PillBarButton prefix='notifications' settings={settings} settingPath={['shows', 'status']} onChange={onChange} label={showStr} />
            <PillBarButton prefix='notifications' settings={settings} settingPath={['sounds', 'status']} onChange={onChange} label={soundStr} />
          </div>
        </div>
      </div>
    );
  }

}
