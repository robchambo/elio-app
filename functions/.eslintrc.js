module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'google',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: ['tsconfig.json'],
    sourceType: 'module',
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: ['/lib/**/*', '/generated/**/*'],
  plugins: ['@typescript-eslint'],
  rules: {
    'quotes': ['error', 'single', {avoidEscape: true}],
    'import/no-unresolved': 0,
    'indent': ['error', 2],
    'object-curly-spacing': ['error', 'never'],
    'max-len': ['warn', {code: 100, ignoreUrls: true, ignoreStrings: true, ignoreTemplateLiterals: true}],
    'require-jsdoc': 0,
    'valid-jsdoc': 0,
    'new-cap': 0,
  },
};
