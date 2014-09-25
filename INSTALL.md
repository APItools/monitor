# Mac OS X
## Homebrew
```bash
brew tap killercup/homebrew-openresty
brew install ngx_openresty

brew install luarocks
luarocks install luajson 1.3.2-1

mkdir -p /usr/local/openresty/nginx/sbin/
ln -s /usr/local/bin/openresty /usr/local/openresty/nginx/sbin/nginx

cd brainslug
rvm use 2.0.0
bundle
foreman start
```

# Linux
```bash
wget http://openresty.org/download/ngx_openresty-1.5.8.1.tar.gz
tar xzf ngx_openresty-1.5.8.1.tar.gz
cd ngx_openresty-1.5.8.1
./configure --with-debug  --with-no-pool-patch --with-http_gunzip_module  # --with-dtrace-probes
make && sudo make install
sudo ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/local/sbin/openresy
```
