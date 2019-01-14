FROM ruby:2.5


COPY backup-remote-*.gem /tmp/

RUN gem install /tmp/backup-remote-*.gem

COPY scripts/entrypoint /usr/local/bin
COPY scripts/config.rb /etc/

ENTRYPOINT /usr/local/bin/entrypoint

