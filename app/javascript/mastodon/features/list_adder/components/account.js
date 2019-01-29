import React from 'react';
import { connect } from 'react-redux';
import { makeGetAccount } from '../../../selectors';
import ImmutablePureComponent from 'react-immutable-pure-component';
import ImmutablePropTypes from 'react-immutable-proptypes';
import Avatar from '../../../components/avatar';
import DisplayName from '../../../components/display_name';
import { injectIntl } from 'react-intl';

const makeMapStateToProps = () => {
  const getAccount = makeGetAccount();

  const mapStateToProps = (state, { accountId }) => ({
    account: getAccount(state, accountId),
  });

  return mapStateToProps;
};


@connect(makeMapStateToProps)
@injectIntl
export default class Account extends ImmutablePureComponent {

  static propTypes = {
    account: ImmutablePropTypes.map.isRequired,
  };

  render () {
    const { account } = this.props;
    return (
      <div className='account'>
        <div className='account__wrapper'>
          <div className='account__display-name'>
            <div className='account__avatar-wrapper'><Avatar account={account} size={36} /></div>
            <DisplayName account={account} />
          </div>
        </div>
      </div>
    );
  }

}
