import js from "@eslint/js";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import globals from "globals";

export default [
  {
    ignores: ["dist", "node_modules"],
  },

  js.configs.recommended,

  {
    files: ["**/*.{js,jsx}"],

    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: globals.browser,
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },

    settings: {
      react: {
        version: "detect",
      },
    },

    plugins: {
      react,
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },

    rules: {
      // React JSX
      ...react.configs.recommended.rules,

      // React Hooks
      ...reactHooks.configs.recommended.rules,

      // Let eslint-plugin-react handle JSX component usage
      "no-unused-vars": "off",

      // React 17+ / React 19 does not require React in scope
      "react/react-in-jsx-scope": "off",

      "react-refresh/only-export-components": [
        "warn",
        {
          allowConstantExport: true,
        },
      ],
    },
  },
];