import React, { CSSProperties } from 'react';
import classNames from 'classnames';
import { autoPlayGif } from '../initial_state';
import { useHovering } from '../../hooks/useHovering';
import { Account } from '../../types/resources';

type Props = {
  account: Account;
  size?: number;
  style?: CSSProperties;
  inline?: Boolean;
  animate?: Boolean;
}

export const Avatar: React.FC<Props> = ({
  account,
  animate = autoPlayGif,
  size = 20,
  inline = false,
  style: styleFromParent,
}) => {

  const { hovering, handleMouseEnter, handleMouseLeave } = useHovering();

  const className = classNames(
    'account__avatar',
    { 'account__avatar-inline': inline },
  );

  const src = account.get('avatar');
  const staticSrc = account.get('avatar_static');
  const style = {
    ...styleFromParent,
    width: `${size}px`,
    height: `${size}px`,
    backgroundSize: `${size}px ${size}px`,
    backgroundImage: (hovering || animate) ? `url(${src})` : `url(${staticSrc})`,
  };

  return (
    <div
      className={className}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      style={style}
    />
  );
};

export default Avatar;
