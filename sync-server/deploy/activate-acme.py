from datetime import datetime, timezone
from pathlib import Path
import subprocess

source = Path('/etc/nginx/sites-available/n8n')
candidate = Path('/opt/study-vault/deploy/n8n-acme.candidate')
original = source.read_bytes()
updated = candidate.read_bytes()
addition = b'    location ^~ /.well-known/acme-challenge/ {\n        root /var/lib/study-vault/acme;\n        default_type text/plain;\n        try_files $uri =404;\n    }\n\n'
if updated == original:
    print('ACME route already installed.')
else:
    assert updated.count(addition) == 1
    assert updated.replace(addition, b'', 1) == original, 'Existing site changed; manual review required.'
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(f'/opt/study-vault/backups/n8n-before-acme-{stamp}.conf')
    with backup.open('xb') as output:
        output.write(original)
    subprocess.run(['install', '-m', '644', str(candidate), str(source)], check=True)
    try:
        subprocess.run(['nginx', '-t'], check=True)
        subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
    except BaseException:
        subprocess.run(['install', '-m', '644', str(backup), str(source)], check=True)
        subprocess.run(['nginx', '-t'], check=True)
        subprocess.run(['systemctl', 'reload', 'nginx'], check=True)
        raise
    print(f'Added only the ACME verification route. Original site backup: {backup}')
