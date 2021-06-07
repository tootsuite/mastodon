import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { connect } from 'react-redux';
import ImmutablePureComponent from 'react-immutable-pure-component';
import { injectIntl } from 'react-intl';
import { setupListEditor, clearListSuggestions, resetListEditor } from '../../actions/lists';
import Account from './components/account';
import Search from './components/search';
import EditListForm from './components/edit_list_form';
import Motion from '../ui/util/optional_motion';
import spring from 'react-motion/lib/spring';

const mapStateToProps = state => ({
  accountIds: state.getIn(['listEditor', 'accounts', 'items']),
  searchAccountIds: state.getIn(['listEditor', 'suggestions', 'items']),
});

const mapDispatchToProps = dispatch => ({
  onInitialize: listId => dispatch(setupListEditor(listId)),
  onClear: () => dispatch(clearListSuggestions()),
  onReset: () => dispatch(resetListEditor()),
});

@connect(mapStateToProps, mapDispatchToProps)
@injectIntl
export default class ListEditor extends ImmutablePureComponent {

  static propTypes = {
    listId: PropTypes.string.isRequired,
    onClose: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
    onInitialize: PropTypes.func.isRequired,
    onClear: PropTypes.func.isRequired,
    onReset: PropTypes.func.isRequired,
    accountIds: ImmutablePropTypes.list.isRequired,
    searchAccountIds: ImmutablePropTypes.list.isRequired,
  };

  componentDidMount () {
    const { onInitialize, listId } = this.props;
    onInitialize(listId);
  }

  componentWillUnmount () {
    const { onReset } = this.props;
    onReset();
  }

  render () {
    const { accountIds, searchAccountIds, onClear } = this.props;
    const showSearch = searchAccountIds.size > 0;

    return (
      <div className='modal-root__modal list-editor'>
        <EditListForm />

        <Search />

        <div className='drawer__pager'>
          <div className='drawer__inner list-editor__accounts'>
            {accountIds.map(accountId => <Account key={accountId} accountId={accountId} added />)}
          </div>

          {showSearch && <div role='button' tabIndex='-1' className='drawer__backdrop' onClick={onClear} />}

          <Motion defaultStyle={{ x: -100 }} style={{ x: spring(showSearch ? 0 : -100, { stiffness: 210, damping: 20 }) }}>
            {({ x }) => (
              <div className='drawer__inner backdrop' style={{ transform: x === 0 ? null : `translateX(${x}%)`, visibility: x === -100 ? 'hidden' : 'visible' }}>
                {searchAccountIds.map(accountId => <Account key={accountId} accountId={accountId} />)}
              </div>
            )}
          </Motion>
        </div>
      </div>
    );
  }

}
