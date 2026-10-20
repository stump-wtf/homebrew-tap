#!/bin/sh
# Find the ruby this box actually has (issue #40).
#
# The homebrew/brew container that runs this repo's CI ships no ruby on
# PATH (run 18702: `ruby: not found`), but brew itself always carries a
# vendored one. macOS and plain Linux dev boxes have ruby on PATH, which
# the first branch covers.
#
# usage: sh scripts/ruby.sh [args...]   run the args under that ruby
#        sh scripts/ruby.sh --which    print the ruby path only

find_ruby() {
    find /home/linuxbrew/.linuxbrew/Homebrew/vendor-portable -path '*/bin/ruby' -type f 2>/dev/null | head -n 1
}

RUBY="$(command -v ruby || true)"
if [ -z "$RUBY" ]; then
    RUBY="$(find_ruby)"
fi
if [ -z "$RUBY" ]; then
    command -v brew >/dev/null 2>&1 && brew vendor-install ruby >/dev/null 2>&1
    RUBY="$(find_ruby)"
fi
if [ -z "$RUBY" ]; then
    echo "no ruby found on PATH or under the Homebrew vendor dir" >&2
    exit 127
fi

if [ "${1:-}" = "--which" ]; then
    echo "$RUBY"
    exit 0
fi

exec "$RUBY" "$@"
