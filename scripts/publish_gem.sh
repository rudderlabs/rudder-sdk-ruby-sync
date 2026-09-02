#!/usr/bin/env bash

set -euo pipefail

readonly GEM_NAME='rudder_analytics_sync'
readonly GEMSPEC_PATH='rudder_analytics_sync.gemspec'
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly RUBYGEMS_API_BASE_URL="${RUBYGEMS_API_BASE_URL:-https://rubygems.org}"
readonly VERIFY_RETRY_COUNT=18
readonly VERIFY_RETRY_DELAY_SECONDS=5

usage() {
  echo "Usage: RELEASE_TAG=v<major>.<minor>.<patch> $0 <validate|verify>" >&2
  exit 1
}

validate_release() {
  if [[ ! "${RELEASE_TAG:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Expected RELEASE_TAG in the form v<major>.<minor>.<patch>, got: ${RELEASE_TAG:-<unset>}" >&2
    exit 1
  fi

  local tag_version="${RELEASE_TAG#v}"
  local source_version
  local gemspec_version
  source_version="$(ruby -Ilib -rrudder_analytics_sync/version -e 'print RudderAnalyticsSync::VERSION')"
  gemspec_version="$(ruby -Ilib -e 'spec = Gem::Specification.load("rudder_analytics_sync.gemspec") or abort "Unable to load gemspec"; print spec.version')"

  if [[ "$tag_version" != "$source_version" ]]; then
    echo "Release tag version ($tag_version) does not match source version ($source_version)." >&2
    exit 1
  fi

  if [[ "$source_version" != "$gemspec_version" ]]; then
    echo "Source version ($source_version) does not match gemspec version ($gemspec_version)." >&2
    exit 1
  fi

  echo "$source_version"
}

verify_published_version() {
  local gem_version="$1"
  local published_version
  local response
  response="$(
    curl \
      --fail \
      --retry "$VERIFY_RETRY_COUNT" \
      --retry-all-errors \
      --retry-delay "$VERIFY_RETRY_DELAY_SECONDS" \
      --silent \
      --show-error \
      --header 'Cache-Control: no-cache' \
      "$RUBYGEMS_API_BASE_URL/api/v2/rubygems/$GEM_NAME/versions/$gem_version.json"
  )"
  published_version="$(
    ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("version")' <<< "$response"
  )"

  if [[ "$published_version" != "$gem_version" ]]; then
    echo "RubyGems returned version $published_version; expected $gem_version." >&2
    exit 1
  fi
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
  fi

  cd "$REPOSITORY_ROOT"

  case "$1" in
    validate)
      validate_release
      ;;
    verify)
      version="$(validate_release)"
      verify_published_version "$version"
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
