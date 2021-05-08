import { decode } from 'blurhash';
import React, { useRef, useEffect, useMemo } from 'react';

const useCanvas = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const canvasCtxRef = React.useRef<CanvasRenderingContext2D | null>(null);
  useEffect(() => {
    if (canvasRef.current) {
      canvasCtxRef.current = canvasRef.current.getContext('2d');
    }
  }, [canvasRef.current]);

  return { canvasRef, canvasCtxRef };
};

const useBlurhashImageData = (hash: string, width: number, height: number) => useMemo(() => new ImageData(decode(hash, width, height), width, height), [hash, width, height]);

type Props = {
  hash: string,
  width?: number,
  height?: number,
  dummy?: boolean,
  [key: string]: any
}

const Blurhash = ({
  hash,
  width = 32,
  height = width,
  dummy = false,
  ...canvasProps
}: Props) => {
  if (dummy || !hash) return null;

  const { canvasRef, canvasCtxRef } = useCanvas();
  try {
    const imageData = useBlurhashImageData(hash, width, height);
    canvasCtxRef.current!.putImageData(imageData, 0, 0);
  } catch (err) {
    console.error('Blurhash decoding failure', { err, hash });
  }

  return <canvas {...canvasProps} ref={canvasRef} width={width} height={height} />;
};

export default Blurhash;
