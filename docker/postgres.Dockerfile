ARG POSTGRES_VERSION=18
FROM docker.io/library/postgres:${POSTGRES_VERSION}

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates pgbackrest \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /etc/pgbackrest /var/log/pgbackrest /var/spool/pgbackrest /var/lib/pgbackrest \
  && chown -R postgres:postgres /var/log/pgbackrest /var/spool/pgbackrest /var/lib/pgbackrest

COPY pgbackrest/pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
COPY pgbackrest/archive-push.sh /usr/local/bin/foah-rss-pgbackrest-archive-push

RUN chmod 644 /etc/pgbackrest/pgbackrest.conf \
  && chmod 755 /usr/local/bin/foah-rss-pgbackrest-archive-push
