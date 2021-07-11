import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import InnerHeader from '../../account/components/header';
import ImmutablePureComponent from 'react-immutable-pure-component';
import MovedNote from './moved_note';
import { FormattedMessage } from 'react-intl';
import { NavLink } from 'react-router-dom';

export default class Header extends ImmutablePureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map,
    identity_proofs: ImmutablePropTypes.list,
    onFollow: PropTypes.func.isRequired,
    onBlock: PropTypes.func.isRequired,
    onMention: PropTypes.func.isRequired,
    onDirect: PropTypes.func.isRequired,
    onReblogToggle: PropTypes.func.isRequired,
    onReport: PropTypes.func.isRequired,
    onMute: PropTypes.func.isRequired,
    onBlockDomain: PropTypes.func.isRequired,
    onUnblockDomain: PropTypes.func.isRequired,
    onEndorseToggle: PropTypes.func.isRequired,
    onAddToList: PropTypes.func.isRequired,
    hideTabs: PropTypes.bool,
    domain: PropTypes.string.isRequired,
  };

  static contextTypes = {
    router: PropTypes.object,
  };

  handleFollow = () => {
    this.props.onFollow(this.props.account);
  }

  handleBlock = () => {
    this.props.onBlock(this.props.account);
  }

  handleMention = () => {
    this.props.onMention(this.props.account, this.context.router.history);
  }

  handleDirect = () => {
    this.props.onDirect(this.props.account, this.context.router.history);
  }

  handleReport = () => {
    this.props.onReport(this.props.account);
  }

  handleReblogToggle = () => {
    this.props.onReblogToggle(this.props.account);
  }

  handleNotifyToggle = () => {
    this.props.onNotifyToggle(this.props.account);
  }

  handleMute = () => {
    this.props.onMute(this.props.account);
  }

  handleBlockDomain = () => {
    const domain = this.props.account.get('acct').split('@')[1];

    if (!domain) return;

    this.props.onBlockDomain(domain);
  }

  handleUnblockDomain = () => {
    const domain = this.props.account.get('acct').split('@')[1];

    if (!domain) return;

    this.props.onUnblockDomain(domain);
  }

  handleEndorseToggle = () => {
    this.props.onEndorseToggle(this.props.account);
  }

  handleAddToList = () => {
    this.props.onAddToList(this.props.account);
  }

  handleEditAccountNote = () => {
    this.props.onEditAccountNote(this.props.account);
  }

  render () {
    const { account, hideTabs, identity_proofs } = this.props;

    if (account === null) {
      return null;
    }

    return (
      <div className='account-timeline__header'>
        {account.get('moved') && <MovedNote from={account} to={account.get('moved')} />}

        <InnerHeader
          account={account}
          identity_proofs={identity_proofs}
          onFollow={this.handleFollow}
          onBlock={this.handleBlock}
          onMention={this.handleMention}
          onDirect={this.handleDirect}
          onReblogToggle={this.handleReblogToggle}
          onNotifyToggle={this.handleNotifyToggle}
          onReport={this.handleReport}
          onMute={this.handleMute}
          onBlockDomain={this.handleBlockDomain}
          onUnblockDomain={this.handleUnblockDomain}
          onEndorseToggle={this.handleEndorseToggle}
          onAddToList={this.handleAddToList}
          onEditAccountNote={this.handleEditAccountNote}
          domain={this.props.domain}
        />

        {!hideTabs && (
          <div className='account__section-headline'>
            <NavLink exact to={`/@${account.get('acct')}`}><FormattedMessage id='account.posts' defaultMessage='Toots' /></NavLink>
            <NavLink exact to={`/@${account.get('acct')}/with_replies`}><FormattedMessage id='account.posts_with_replies' defaultMessage='Toots and replies' /></NavLink>
            <NavLink exact to={`/@${account.get('acct')}/media`}><FormattedMessage id='account.media' defaultMessage='Media' /></NavLink>
          </div>
        )}
      </div>
    );
  }

}
