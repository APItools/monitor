#!/bin/sh
set -e

export DISPLAY=:99.0

export SLUG_REDIS_HOST=127.0.0.1

eval $(luarocks path) # include luarocks load paths

dotenv supervisord -n &

exec bundle exec rake integrate
