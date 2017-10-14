// Like react-motion's Motion, but checks to see if the user prefers
// reduced motion and uses a cross-fade in those cases.

import Motion from 'react-motion/lib/Motion';
import { connect } from 'react-redux';
import { pick } from 'lodash';

const stylesToKeep = ['opacity', 'backgroundOpacity'];

const extractValue = (value) => {
  // This is either an object with a "val" property or it's a number
  return (typeof value === 'object' && value && 'val' in value) ? value.val : value;
};

const reduceMotionFromOptions = (styles) => {
  return pick(styles, stylesToKeep);
};

const mapStateToProps = (state, ownProps) => {
  const reduceMotion = state.getIn(['meta', 'reduce_motion']);

  if (reduceMotion) {
    const oldStyle = ownProps.style;
    const oldDefaultStyle = ownProps.defaultStyle;
    const style = reduceMotionFromOptions(oldStyle);
    const defaultStyle = reduceMotionFromOptions(oldDefaultStyle);

    Object.keys(oldStyle).forEach(key => {
      if (stylesToKeep.includes(key)) {
        return;
      }
      // If it's setting an x or height or scale or some other value, we need
      // to preserve the end-state value without actually animating it
      style[key] = defaultStyle[key] = extractValue(oldStyle[key]);
    });

    return { style, defaultStyle };
  }
  return {};
};

export default connect(mapStateToProps)(Motion);
