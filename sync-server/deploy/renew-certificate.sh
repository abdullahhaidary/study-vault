set -euo pipefail
exec 9>/run/lock/study-vault-cert.lock
flock -n 9 || exit 0
docker run --rm --network host \
  --volume /opt/study-vault/tls/config:/etc/letsencrypt \
  --volume /opt/study-vault/tls/work:/var/lib/letsencrypt \
  --volume /opt/study-vault/tls/logs:/var/log/letsencrypt \
  --volume /var/lib/study-vault/acme:/var/www/acme \
  certbot/certbot:v5.4.0 renew --cert-name study-vault-ip --quiet
nginx -t
systemctl reload nginx
openssl x509 -checkend 86400 -noout -in /opt/study-vault/tls/config/live/study-vault-ip/fullchain.pem
