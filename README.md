# APItools Traffic Monitor

# Install Guide
You can find the full Install Guide in [our documentation](https://docs.apitools.com/docs/on-premise/).

## Debian/Ubuntu

* For Ubuntu > 13.04 you can use `https://s3.amazonaws.com/apitoolsrepo/packages/ubuntu/13.04/latest`  
* For Ubuntu 12.04 `https://s3.amazonaws.com/apitoolsrepo/packages/ubuntu/12.04/latest`  
* For Debian `https://s3.amazonaws.com/apitoolsrepo/packages/debian/7.2/latest`  

```
wget https://s3.amazonaws.com/apitoolsrepo/packages/ubuntu/12.04/latest -O apitools.deb
dpkg -i apitools.deb
```

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

## OSX

On OSX instead of `nginx` use `openresty`.


# Contributing

We can't accept Pull Requests just now.
For contributing guide check [CONTRIBUTING.md](CONTRIBUTING.md).
