set -euo pipefail
umask 077
exec 9>/run/lock/study-vault-backup.lock
flock -n 9 || exit 0
cd /opt/study-vault
install -d -m 700 backups
available=$(df --output=avail -B1 backups | tail -1)
if (( available < 10737418240 )); then
  printf '%s\n' 'Backup stopped: less than 10 GiB free. Move older backups off-server.' >&2
  exit 1
fi
destination=$(mktemp -d "backups/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
docker compose exec -T db pg_dump -U study_vault -d study_vault --format=custom > "$destination/database.dump"
docker compose exec -T api tar -C /data/files -cf - . | gzip > "$destination/files.tar.gz"
docker compose exec -T db pg_restore --list < "$destination/database.dump" > /dev/null
gzip -t "$destination/files.tar.gz"
(cd "$destination" && sha256sum database.dump files.tar.gz > SHA256SUMS)
printf '%s\n' "Backup complete: $destination"
