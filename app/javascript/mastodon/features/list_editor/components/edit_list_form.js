import React from 'react';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { changeListEditorTitle, submitListEditor } from '../../../actions/lists';
import IconButton from '../../../components/icon_button';
import { defineMessages, injectIntl } from 'react-intl';

const messages = defineMessages({
  title: { id: 'lists.edit.submit', defaultMessage: 'Change title' },
});

const mapStateToProps = state => ({
  value: state.getIn(['listEditor', 'title']),
  disabled: !state.getIn(['listEditor', 'isChanged']) || !state.getIn(['listEditor', 'title']),
});

const mapDispatchToProps = dispatch => ({
  onChange: value => dispatch(changeListEditorTitle(value)),
  onSubmit: () => dispatch(submitListEditor(false)),
});

@connect(mapStateToProps, mapDispatchToProps)
@injectIntl
export default class ListForm extends React.PureComponent {

  static propTypes = {
    value: PropTypes.string.isRequired,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onChange: PropTypes.func.isRequired,
    onSubmit: PropTypes.func.isRequired,
  };

  handleChange = e => {
    this.props.onChange(e.target.value);
  }

  handleSubmit = e => {
    e.preventDefault();
    this.props.onSubmit();
  }

  handleClick = () => {
    this.props.onSubmit();
  }

  render () {
    const { value, disabled, intl } = this.props;

    const title = intl.formatMessage(messages.title);

    return (
      <form className='column-inline-form' onSubmit={this.handleSubmit}>
        <input
          className='setting-text'
          value={value}
          onChange={this.handleChange}
        />

        <IconButton
          disabled={disabled}
          icon='check'
          title={title}
          onClick={this.handleClick}
        />
      </form>
    );
  }

}
