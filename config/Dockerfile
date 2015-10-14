FROM quay.io/3scale/openresty:1.7.4.1

MAINTAINER Michal Cichra <michal@3scale.net> # 2014-02-24

RUN luarocks install luajson \
 && luarocks install luaexpat

RUN ln -sf /var/www/brainslug/config/supervisor.conf /etc/supervisor/conf.d/openresty.conf \
 && ln -sf /var/www/brainslug/config/logrotate.conf /etc/logrotate.d/nginx \
 && rm /etc/supervisor/conf.d/cron.conf

ENV SLUG_LOGFILE /var/log/supervisor/supervisord.log
ENV SLUG_CSRF_PROTECTION 1;

CMD ["supervisord", "-n"]
EXPOSE 7071 10002

WORKDIR /var/www/brainslug
ADD . /var/www/brainslug
