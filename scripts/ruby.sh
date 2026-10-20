#!/bin/sh
# Find The Ruby This Box Actually Has
#
# Resolves a usable ruby interpreter for the tap-bump tooling: PATH first,
# then Homebrew's vendored portable-ruby (the homebrew/brew CI container
# ships brew but no ruby on PATH). Usage:
#   sh scripts/ruby.sh [args...]   run the args under that ruby
#   sh scripts/ruby.sh --which     print the ruby path only
#
# @joestump-agent 10/20/2026 - Created for issue #40 after run 18702 died on
#   `ruby: not found` inside homebrew/brew.
#
# @joestump-agent 10/20/2026 - Fix the vendor probe: the portable-ruby lives
#   at Library/Homebrew/vendor/portable-ruby/<version>/bin/ruby (with a
#   `current` symlink), not Homebrew/vendor-portable, so run 18704 still
#   failed in the container. Probe both the Linuxbrew and macOS prefixes.

find_ruby() {
    for root in \
        /home/linuxbrew/.linuxbrew/Homebrew \
        /opt/homebrew/Homebrew \
        /usr/local/Homebrew
    do
        for candidate in \
            "$root"/Library/Homebrew/vendor/portable-ruby/current/bin/ruby \
            "$root"/Library/Homebrew/vendor/portable-ruby/*/bin/ruby
        do
            if [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
    done
    return 1
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
