export default {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [2, "always", ["feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore"]],
    "header-max-length": [2, "always", 72],
    "subject-full-stop": [2, "never", "."],
    "body-empty": [2, "always"],
    "footer-empty": [2, "always"],
    "trailer-exists": [0],
  },
};
