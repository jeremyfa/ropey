#!/bin/bash
# Build and run the tests with Node.js, with the default tree sizes and with
# the small ones ropey uses in its own unit tests.
# Usage: ./run.sh [filter]
set -e
cd "$(dirname "$0")"
HAXE="${HAXE:-haxe}"
"$HAXE" build.hxml
node bin/test.js "$@"
"$HAXE" build-small.hxml
node bin/test-small.js "$@"
