#!/bin/sh
# The rules tests, with the coverage floor. The QML is checked by running it: see README,
# "Working on it".
set -eu
cd "$(dirname "$0")/.."
exec node --test --experimental-test-coverage \
    --test-coverage-include='omdrop/lib/*.js' \
    --test-coverage-lines=95 --test-coverage-branches=95 --test-coverage-functions=95 \
    tests/*_unit.js
