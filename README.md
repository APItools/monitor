# APItools Traffic Monitor

# Install Guide
You can find the full Install Guide in [our documentation](https://docs.apitools.com/docs/on-premise/).


## Debian/Ubuntu

See https://packagecloud.io/APItools/monitor/install how to add our repositories.
Then you can use `apt-get install apitools-monitor` to install APItools Monitor.

We recommend installing `supervisor` and `redis-server` packages to make it work on one machine.

## OSX

Install [homebrew](http://brew.sh/)

```bash
brew tap killercup/homebrew-openresty
brew install ngx_openresty --with-gunzip --with-luajit-checkhook
brew install luarocks

luarocks install luajson sha2 luaexpat
```

# Running it

```bash
nginx -p /path/to/folder -c config/nginx.conf
```

And APItools will start listening on port 7071 and 10002.

## OSX

On OSX instead of `nginx` use `openresty`.


# Contributing

We can't accept Pull Requests just now.
For contributing guide check [CONTRIBUTING.md](CONTRIBUTING.md).
