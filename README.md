# FOAH RSS

FOAH RSS production runs as rootless Podman Quadlets. Miniflux joins the shared
external `reverse-proxy.network`, so the reverse proxy can reach it without
publishing another host port.

Deploy the shared reverse proxy first so `reverse-proxy.network` exists, then
deploy FOAH RSS:

```sh
cp .env.example .env
$EDITOR .env
./deploy.sh
```

## pgBackRest Backups

```sh
./backup.sh full
./backup.sh diff
./backup.sh incr
```

The deploy script installs and enables user-level timers when
`PGBACKREST_ENABLED=1`:

```sh
systemctl --user list-timers 'foah-rss-backup*'
```
