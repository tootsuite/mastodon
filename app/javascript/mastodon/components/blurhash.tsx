// @ts-check

import { decode } from 'blurhash';
import React, { useRef, useEffect } from 'react';
import PropTypes from 'prop-types';

/**
 * @typedef BlurhashPropsBase
 * @property {string?} hash Hash to render
 * @property {number} width
 * Width of the blurred region in pixels. Defaults to 32
 * @property {number} [height]
 * Height of the blurred region in pixels. Defaults to width
 * @property {boolean} [dummy]
 * Whether dummy mode is enabled. If enabled, nothing is rendered
 * and canvas left untouched
 */

/** @typedef {JSX.IntrinsicElements['canvas'] & BlurhashPropsBase} BlurhashProps */

/**
 * Component that is used to render blurred of blurhash string
 *
 * @param {BlurhashProps} param1 Props of the component
 * @returns Canvas which will render blurred region element to embed
 */
function Blurhash({
  hash,
  width = 32,
  height = width,
  dummy = false,
  ...canvasProps
}) {
  const canvasRef = /** @type {import('react').MutableRefObject<HTMLCanvasElement>} */ (useRef());

  useEffect(() => {
    const { current: canvas } = canvasRef;
    canvas.width = canvas.width; // resets canvas

    if (dummy || !hash) return;

    try {
      const pixels = decode(hash, width, height);
      const ctx = canvas.getContext('2d');
      const imageData = new ImageData(pixels, width, height);

      ctx.putImageData(imageData, 0, 0);
    } catch (err) {
      console.error('Blurhash decoding failure', { err, hash });
    }
  }, [dummy, hash, width, height]);

  return (
    <canvas {...canvasProps} ref={canvasRef} width={width} height={height} />
  );
}

Blurhash.propTypes = {
  hash: PropTypes.string.isRequired,
  width: PropTypes.number,
  height: PropTypes.number,
  dummy: PropTypes.bool,
};

export default React.memo(Blurhash);
