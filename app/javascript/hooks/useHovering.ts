import { useCallback, useState } from 'react';

export const useHovering = () => {
  const [hovering, setHovering] = useState<boolean>(false);

  const handleMouseEnter = useCallback(() => setHovering(true), [setHovering])
  const handleMouseLeave = useCallback(() => setHovering(false), [setHovering])

  return { hovering, handleMouseEnter, handleMouseLeave };
};
