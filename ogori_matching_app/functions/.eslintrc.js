module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
  ],
  parser: "@typescript-eslint/parser", // ⭐ TypeScriptパーサーを追加
  parserOptions: {
    ecmaVersion: 2018,
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*",
  ],
  rules: {
    // 全ルール無効化
    "no-unused-vars": "off",
    "no-undef": "off",
    "require-jsdoc": "off",
  },
};
