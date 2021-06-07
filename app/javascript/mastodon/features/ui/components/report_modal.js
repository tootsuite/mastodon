import React from 'react';
import { connect } from 'react-redux';
import { changeReportComment, changeReportForward, submitReport } from '../../../actions/reports';
import { expandAccountTimeline } from '../../../actions/timelines';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { makeGetAccount } from '../../../selectors';
import { defineMessages, FormattedMessage, injectIntl } from 'react-intl';
import StatusCheckBox from '../../report/containers/status_check_box_container';
import { OrderedSet } from 'immutable';
import ImmutablePureComponent from 'react-immutable-pure-component';
import Button from '../../../components/button';
import Toggle from 'react-toggle';
import IconButton from '../../../components/icon_button';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
  placeholder: { id: 'report.placeholder', defaultMessage: 'Additional comments' },
  submit: { id: 'report.submit', defaultMessage: 'Submit' },
});

const makeMapStateToProps = () => {
  const getAccount = makeGetAccount();

  const mapStateToProps = state => {
    const accountId = state.getIn(['reports', 'new', 'account_id']);

    return {
      isSubmitting: state.getIn(['reports', 'new', 'isSubmitting']),
      account: getAccount(state, accountId),
      comment: state.getIn(['reports', 'new', 'comment']),
      forward: state.getIn(['reports', 'new', 'forward']),
      statusIds: OrderedSet(state.getIn(['timelines', `account:${accountId}:with_replies`, 'items'])).union(state.getIn(['reports', 'new', 'status_ids'])),
    };
  };

  return mapStateToProps;
};

@connect(makeMapStateToProps)
@injectIntl
export default class ReportModal extends ImmutablePureComponent {

  static propTypes = {
    isSubmitting: PropTypes.bool,
    account: ImmutablePropTypes.map,
    statusIds: ImmutablePropTypes.orderedSet.isRequired,
    comment: PropTypes.string.isRequired,
    forward: PropTypes.bool,
    dispatch: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleCommentChange = e => {
    this.props.dispatch(changeReportComment(e.target.value));
  }

  handleForwardChange = e => {
    this.props.dispatch(changeReportForward(e.target.checked));
  }

  handleSubmit = () => {
    this.props.dispatch(submitReport());
  }

  handleKeyDown = e => {
    if (e.keyCode === 13 && (e.ctrlKey || e.metaKey)) {
      this.handleSubmit();
    }
  }

  componentDidMount () {
    this.props.dispatch(expandAccountTimeline(this.props.account.get('id'), { withReplies: true }));
  }

  componentWillReceiveProps (nextProps) {
    if (this.props.account !== nextProps.account && nextProps.account) {
      this.props.dispatch(expandAccountTimeline(nextProps.account.get('id'), { withReplies: true }));
    }
  }

  render () {
    const { account, comment, intl, statusIds, isSubmitting, forward, onClose } = this.props;

    if (!account) {
      return null;
    }

    const domain = account.get('acct').split('@')[1];

    return (
      <div className='modal-root__modal report-modal'>
        <div className='report-modal__target'>
          <IconButton className='report-modal__close' title={intl.formatMessage(messages.close)} icon='times' onClick={onClose} size={20} />
          <FormattedMessage id='report.target' defaultMessage='Report {target}' values={{ target: <strong>{account.get('acct')}</strong> }} />
        </div>

        <div className='report-modal__container'>
          <div className='report-modal__comment'>
            <p><FormattedMessage id='report.hint' defaultMessage='The report will be sent to your server moderators. You can provide an explanation of why you are reporting this account below:' /></p>

            <textarea
              className='setting-text light'
              placeholder={intl.formatMessage(messages.placeholder)}
              value={comment}
              onChange={this.handleCommentChange}
              onKeyDown={this.handleKeyDown}
              disabled={isSubmitting}
              autoFocus
            />

            {domain && (
              <div>
                <p><FormattedMessage id='report.forward_hint' defaultMessage='The account is from another server. Send an anonymized copy of the report there as well?' /></p>

                <div className='setting-toggle'>
                  <Toggle id='report-forward' checked={forward} disabled={isSubmitting} onChange={this.handleForwardChange} />
                  <label htmlFor='report-forward' className='setting-toggle__label'><FormattedMessage id='report.forward' defaultMessage='Forward to {target}' values={{ target: domain }} /></label>
                </div>
              </div>
            )}

            <Button disabled={isSubmitting} text={intl.formatMessage(messages.submit)} onClick={this.handleSubmit} />
          </div>

          <div className='report-modal__statuses'>
            <div>
              {statusIds.map(statusId => <StatusCheckBox id={statusId} key={statusId} disabled={isSubmitting} />)}
            </div>
          </div>
        </div>
      </div>
    );
  }

}
