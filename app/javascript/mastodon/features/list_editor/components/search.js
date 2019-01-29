import React from 'react';
import PropTypes from 'prop-types';
import { connect } from 'react-redux';
import { defineMessages, injectIntl } from 'react-intl';
import { fetchListSuggestions, clearListSuggestions, changeListSuggestions } from '../../../actions/lists';
import classNames from 'classnames';
import Icon from 'mastodon/components/icon';

const messages = defineMessages({
  search: { id: 'lists.search', defaultMessage: 'Search among people you follow' },
});

const mapStateToProps = state => ({
  value: state.getIn(['listEditor', 'suggestions', 'value']),
});

const mapDispatchToProps = dispatch => ({
  onSubmit: value => dispatch(fetchListSuggestions(value)),
  onClear: () => dispatch(clearListSuggestions()),
  onChange: value => dispatch(changeListSuggestions(value)),
});

@connect(mapStateToProps, mapDispatchToProps)
@injectIntl
export default class Search extends React.PureComponent {

  static propTypes = {
    intl: PropTypes.object.isRequired,
    value: PropTypes.string.isRequired,
    onChange: PropTypes.func.isRequired,
    onSubmit: PropTypes.func.isRequired,
    onClear: PropTypes.func.isRequired,
  };

  handleChange = e => {
    this.props.onChange(e.target.value);
  }

  handleKeyUp = e => {
    if (e.keyCode === 13) {
      this.props.onSubmit(this.props.value);
    }
  }

  handleClear = () => {
    this.props.onClear();
  }

  render () {
    const { value, intl } = this.props;
    const hasValue = value.length > 0;

    return (
      <div className='list-editor__search search'>
        <label>
          <span style={{ display: 'none' }}>{intl.formatMessage(messages.search)}</span>

          <input
            className='search__input'
            type='text'
            value={value}
            onChange={this.handleChange}
            onKeyUp={this.handleKeyUp}
            placeholder={intl.formatMessage(messages.search)}
          />
        </label>

        <div role='button' tabIndex='0' className='search__icon' onClick={this.handleClear}>
          <Icon id='search' className={classNames({ active: !hasValue })} />
          <Icon id='times-circle' aria-label={intl.formatMessage(messages.search)} className={classNames({ active: hasValue })} />
        </div>
      </div>
    );
  }

}
