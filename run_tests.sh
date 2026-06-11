#!/usr/bin/env bash
# Run all Lua unit tests
set -e
cd "$(dirname "$0")"
lua5.3 tests/test_lib.lua -v
