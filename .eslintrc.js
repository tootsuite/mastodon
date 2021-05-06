module.exports = {
  root: true,

  env: {
    browser: true,
    node: true,
    es6: true,
    jest: true,
  },

  globals: {
    ATTACHMENT_HOST: false,
  },

  parser: '@typescript-eslint/parser',

  plugins: [
    'react',
    'jsx-a11y',
    'import',
    'promise',
  ],

  parserOptions: {
    sourceType: 'module',
    ecmaFeatures: {
      experimentalObjectRestSpread: true,
      legacyDecorators: true,
      jsx: true,
    },
    ecmaVersion: 2018,
  },

  settings: {
    react: {
      version: 'detect',
    },
    'import/resolver': {
      node:[
        '.js',
        '.ts',
        '.tsx',
      ]
    },
    'import/ignore': [
      'node_modules',
      '\\.(css|scss|json)$',
    ],
    'import/resolver': {
      node: {
        paths: ['app/javascript'],
      },
    },
  },

  rules: {
    'brace-style': 'warn',
    'comma-dangle': ['error', 'always-multiline'],
    'comma-spacing': [
      'warn',
      {
        before: false,
        after: true,
      },
    ],
    'comma-style': ['warn', 'last'],
    'consistent-return': 'error',
    'dot-notation': 'error',
    eqeqeq: 'error',
    indent: ['warn', 2],
    'jsx-quotes': ['error', 'prefer-single'],
    'no-catch-shadow': 'error',
    'no-cond-assign': 'error',
    'no-console': [
      'warn',
      {
        allow: [
          'error',
          'warn',
        ],
      },
    ],
    'no-fallthrough': 'error',
    'no-irregular-whitespace': 'error',
    'no-mixed-spaces-and-tabs': 'warn',
    'no-nested-ternary': 'warn',
    'no-trailing-spaces': 'warn',
    'no-undef': 'error',
    'no-unreachable': 'error',
    'no-unused-expressions': 'error',
    'no-unused-vars': [
      'error',
      {
        vars: 'all',
        args: 'after-used',
        ignoreRestSiblings: true,
      },
    ],
    'object-curly-spacing': ['error', 'always'],
    'padded-blocks': [
      'error',
      {
        classes: 'always',
      },
    ],
    quotes: ['error', 'single'],
    semi: 'error',
    strict: 'off',
    'valid-typeof': 'error',

    'react/jsx-boolean-value': 'error',
    'react/jsx-closing-bracket-location': ['error', 'line-aligned'],
    'react/jsx-curly-spacing': 'error',
    'react/jsx-equals-spacing': 'error',
    'react/jsx-first-prop-new-line': ['error', 'multiline-multiprop'],
    'react/jsx-indent': ['error', 2],
    'react/jsx-no-bind': 'error',
    'react/jsx-no-duplicate-props': 'error',
    'react/jsx-no-undef': 'error',
    'react/jsx-tag-spacing': 'error',
    'react/jsx-uses-react': 'error',
    'react/jsx-uses-vars': 'error',
    'react/jsx-wrap-multilines': 'error',
    'react/no-multi-comp': 'off',
    'react/no-string-refs': 'error',
    'react/prop-types': 'error',
    'react/self-closing-comp': 'error',

    'jsx-a11y/accessible-emoji': 'warn',
    'jsx-a11y/alt-text': 'warn',
    'jsx-a11y/anchor-has-content': 'warn',
    'jsx-a11y/anchor-is-valid': [
      'warn',
      {
        components: [
          'Link',
          'NavLink',
        ],
        specialLink: [
          'to',
        ],
        aspect: [
          'noHref',
          'invalidHref',
          'preferButton',
        ],
      },
    ],
    'jsx-a11y/aria-activedescendant-has-tabindex': 'warn',
    'jsx-a11y/aria-props': 'warn',
    'jsx-a11y/aria-proptypes': 'warn',
    'jsx-a11y/aria-role': 'warn',
    'jsx-a11y/aria-unsupported-elements': 'warn',
    'jsx-a11y/heading-has-content': 'warn',
    'jsx-a11y/html-has-lang': 'warn',
    'jsx-a11y/iframe-has-title': 'warn',
    'jsx-a11y/img-redundant-alt': 'warn',
    'jsx-a11y/interactive-supports-focus': 'warn',
    'jsx-a11y/label-has-for': 'off',
    'jsx-a11y/mouse-events-have-key-events': 'warn',
    'jsx-a11y/no-access-key': 'warn',
    'jsx-a11y/no-distracting-elements': 'warn',
    'jsx-a11y/no-noninteractive-element-interactions': [
      'warn',
      {
        handlers: [
          'onClick',
        ],
      },
    ],
    'jsx-a11y/no-onchange': 'warn',
    'jsx-a11y/no-redundant-roles': 'warn',
    'jsx-a11y/no-static-element-interactions': [
      'warn',
      {
        handlers: [
          'onClick',
        ],
      },
    ],
    'jsx-a11y/role-has-required-aria-props': 'warn',
    'jsx-a11y/role-supports-aria-props': 'off',
    'jsx-a11y/scope': 'warn',
    'jsx-a11y/tabindex-no-positive': 'warn',

    'import/extensions': [
      'error',
      'always',
      {
        js: 'never',
        ts: 'never',
        tsx: 'never',
      },
    ],
    'import/newline-after-import': 'error',
    'import/no-extraneous-dependencies': [
      'error',
      {
        devDependencies: [
          'config/webpack/**',
          'app/javascript/mastodon/test_setup.js',
          'app/javascript/**/__tests__/**',
        ],
      },
    ],
    'import/no-unresolved': 'error',
    'import/no-webpack-loader-syntax': 'error',

    'promise/catch-or-return': [
      'error',
      {
        allowFinally: true,
      },
    ],
  },
};
