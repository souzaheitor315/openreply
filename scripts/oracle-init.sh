#!/usr/bin/env bash
# Run ON THE VM, in the root of the OpenReply repository:
#   bash scripts/oracle-init.sh
# Generates secrets locally; never commits or displays them.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -e .env ]]; then
  echo "Arquivo .env ja existe. Nao vou sobrescrever suas credenciais."
  exit 1
fi

if [[ ! -f oracle.env.example ]]; then
  echo "Arquivo oracle.env.example nao encontrado."
  exit 1
fi

umask 077
python3 - <<'PY'
from pathlib import Path
import secrets

template = Path("oracle.env.example").read_text()
database_password = secrets.token_hex(24)
template = template.replace("replace-with-openssl-rand-hex-24", database_password)
template = template.replace("replace-with-openssl-rand-base64-32", secrets.token_hex(32), 1)
template = template.replace("replace-with-openssl-rand-base64-32", secrets.token_hex(32), 1)
template = template.replace("replace-with-openssl-rand-hex-32", secrets.token_hex(32), 1)
template = template.replace(
    "\nWEBHOOK_VERIFY_TOKEN=\n",
    "\nWEBHOOK_VERIFY_TOKEN=" + secrets.token_hex(24) + "\n",
    1,
)
env_file = Path(".env")
with env_file.open("x") as output:
    output.write(template)
env_file.chmod(0o600)
print("Arquivo .env gerado com segredos fortes; nenhuma senha foi exibida.")
print("Edite SITE_DOMAIN, NEXTAUTH_URL, ALLOWED_EMAILS, EMAIL_FROM")
print("e configure EMAIL_SERVER ou RESEND_API_KEY antes de iniciar.")
print("A conexao do Instagram (variaveis META/INSTAGRAM) pode ser feita depois.")
PY
