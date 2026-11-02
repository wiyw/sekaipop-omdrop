#!/bin/sh
# The rules tests, with the coverage floor, and the bundled link opener. The QML is checked by
# running it: see README, "development".
set -eu
cd "$(dirname "$0")/.."
node --test --experimental-test-coverage \
    --test-coverage-include='omdrop/lib/*.js' \
    --test-coverage-lines=95 --test-coverage-branches=95 --test-coverage-functions=95 \
    tests/*_unit.js
python3 -m unittest discover -s tests -p 'test_open_link.py'
