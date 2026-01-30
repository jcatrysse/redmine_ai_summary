#!/usr/bin/env bash
set -euo pipefail

REDMINE_DIR="${REDMINE_DIR:-redmine}"
PLUGIN_NAME="$(basename "$(pwd)")"
MISE_BIN="${MISE_BIN:-mise}"

detect_ruby_version() {
  local version=""

  if [ -f ".ruby-version" ]; then
    version="$(tr -d '\n' < .ruby-version)"
  elif [ -f "Gemfile" ]; then
    local ruby_line=""
    ruby_line="$(grep -E "^[[:space:]]*ruby " Gemfile | head -n 1 || true)"

    version="$(echo "$ruby_line" | sed -E -n "s/.*ruby[[:space:]]*['\\\"]([0-9]+\\.[0-9]+(\\.[0-9]+)?)[\"'].*$/\\1/p")"
    if [ -z "$version" ]; then
      version="$(echo "$ruby_line" | sed -E -n "s/.*~>[[:space:]]*([0-9]+\\.[0-9]+(\\.[0-9]+)?).*/\\1/p")"
    fi
    if [ -z "$version" ]; then
      local upper=""
      upper="$(echo "$ruby_line" | sed -E -n "s/.*<[[:space:]]*([0-9]+\\.[0-9]+(\\.[0-9]+)?).*/\\1/p")"
      if [ -n "$upper" ]; then
        local major="${upper%%.*}"
        local minor="${upper#*.}"
        minor="${minor%%.*}"
        if [ "$minor" -gt 0 ]; then
          minor=$((minor - 1))
        fi
        version="${major}.${minor}"
      fi
    fi
  fi

  echo "$version"
}

cd "$REDMINE_DIR"
mkdir -p tmp/test-results

RUBY_VERSION="$(detect_ruby_version)"

plugin_root="plugins/$PLUGIN_NAME"

if [ -d "$plugin_root/spec" ]; then
  TEST_CMD="bundle exec rspec \"$plugin_root/spec\" --format progress"
elif [ -d "$plugin_root/test" ]; then
  TEST_CMD="bundle exec rails test \"$plugin_root/test\""
else
  echo "No spec/ or test/ directory found for $PLUGIN_NAME. Nothing to run." >&2
  exit 1
fi

if [ -n "$RUBY_VERSION" ]; then
  if command -v "$MISE_BIN" >/dev/null 2>&1; then
    "$MISE_BIN" exec "ruby@$RUBY_VERSION" -- bash -lc "$TEST_CMD"
  else
    echo "mise is required to run tests with Ruby $RUBY_VERSION. Please run ./.codex/test_setup.sh first." >&2
    exit 1
  fi
else
  if ! command -v bundle >/dev/null 2>&1; then
    echo "Bundler is not available. Please run ./.codex/test_setup.sh first." >&2
    exit 1
  fi
  bash -lc "$TEST_CMD"
fi
