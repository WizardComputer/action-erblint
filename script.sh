#!/bin/sh -e

if [ -n "${GITHUB_WORKSPACE}" ]
then
    git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
    git config --global --add safe.directory "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1
    cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo '::group:: Installing erb-lint with extensions ... https://github.com/Shopify/erb-lint'
# if 'gemfile' erb-lint version selected
if [ "$INPUT_ERBLINT_VERSION" = "gemfile" ]; then
  # if Gemfile.lock is here
  if [ -f 'Gemfile.lock' ]; then
    # grep for erb-lint version
    ERBLINT_GEMFILE_VERSION=$(ruby -ne 'print $& if /^\s{4}erb_lint\s\(\K.*(?=\))/' Gemfile.lock)

    # if erb-lint version found, then pass it to the gem install
    # left it empty otherwise, so no version will be passed
    if [ -n "$ERBLINT_GEMFILE_VERSION" ]; then
      ERBLINT_VERSION=$ERBLINT_GEMFILE_VERSION
      else
        printf "Cannot get the erb-lint's version from Gemfile.lock. The latest version will be installed."
    fi
    else
      printf 'Gemfile.lock not found. The latest version will be installed.'
  fi
  else
    # set desired erb-lint version
    ERBLINT_VERSION=$INPUT_ERBLINT_VERSION
fi

gem install -N erb_lint --version "${ERBLINT_VERSION}"
echo '::endgroup::'

echo '::group:: Running erb-lint with reviewdog 🐶 ...'
erblint --lint-all --format compact \
  | reviewdog \
      -efm="%f:%l:%c: %m" \
      -reporter="${INPUT_REPORTER}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -level="${INPUT_LEVEL}"
echo '::endgroup::'
