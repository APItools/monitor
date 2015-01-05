#!/bin/sh
set -e

redis-server > /dev/null &
dotenv openresty -p release -c config/nginx.conf &

exec script/jenkins.sh bash
