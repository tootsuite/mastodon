const { join, resolve } = require('path');
const { env, settings } = require('../configuration');

module.exports = {
  test: /\.(js|jsx|mjs|ts|tsx)$/,
  include: [
    settings.source_path,
    ...settings.resolved_paths,
  ].map(p => resolve(p)),
  exclude: /node_modules/,
  use: [
    {
      loader: 'babel-loader',
      options: {
        cacheDirectory: join(settings.cache_path, 'babel-loader'),
        cacheCompression: env.NODE_ENV === 'production',
        compact: env.NODE_ENV === 'production',
      },
    },
  ],
};
