# FROM quay.io/3scale/ruby:2.0
FROM quay.io/3scale/openresty:1.7.4.1

MAINTAINER Michal Cichra <michal@3scale.net> # 2014-06-13

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6 \
 && echo 'deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu precise main' > /etc/apt/sources.list.d/ruby-ng.list \
 && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 136221EE520DDFAF0A905689B9316A7BC7917B12 \
 && echo 'deb http://ppa.launchpad.net/chris-lea/node.js/ubuntu precise main' > /etc/apt/sources.list.d/nodejs.list \
 && apt-get -y -q update \
 && apt-get -y -q install ruby2.1 git-core ruby2.1-dev rubygems ruby-switch \
 && ruby-switch --set ruby2.1 \
 && gem install bundler --no-rdoc --no-ri \
 && apt-get -y -q install xvfb firefox=28.0+build2-0ubuntu2 libqt4-dev \
 && apt-get -y -q install nodejs \
 && apt-get -y -q install libssl-dev openssl

RUN bundle config --global without development \
 && bundle config --global jobs `grep -c processor /proc/cpuinfo` \
 && npm install -g karma-cli

RUN ln -s /opt/openresty/nginx/sbin/nginx /usr/local/sbin/openresty

ADD ./luarocks /root/luarocks/
RUN luarocks install /root/luarocks/lunit*.rock \
 && luarocks install /root/luarocks/lpeg*.rock \
 && luarocks install /root/luarocks/luaexpat*.rock \
 && luarocks install /root/luarocks/luajson*.rock \
 && rm -rf /root/luarocks \
 && luarocks install busted-stable

ENV RELEASE test

WORKDIR /tmp/slug/

ADD Gemfile Gemfile.lock /tmp/slug/
RUN bundle install

ADD package.json /tmp/slug/
RUN npm install

RUN ln -sf /opt/slug/config/supervisor.conf /etc/supervisor/conf.d/openresty.conf \
 && mkdir -p /var/www \
 && ln -sf /opt/slug/release/ /var/www/brainslug

WORKDIR /opt/slug/
ADD . /opt/slug

RUN rm -rf /opt/slug/node_modules \
 && mv -f /tmp/slug/node_modules /opt/slug/ \
 && ln -sf /opt/openresty/nginx/sbin/nginx /usr/local/bin/

ENV SLUG_ENV test
RUN rake release -- -y
CMD ["script/docker.sh"]
EXPOSE 7071 1002
