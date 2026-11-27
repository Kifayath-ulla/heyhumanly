#!/bin/zsh
# Creates a free, self-signed code-signing identity for release builds. A fixed certificate keeps the app's designated
# requirement the same across updates, so macOS keeps the Accessibility permission (ad-hoc builds lose it every update).
# It is NOT an Apple Developer ID: Gatekeeper still treats the app as unnotarized.
# Usage: scripts/make-signing-cert.sh [out-dir]   then add the two printed values as GitHub Actions secrets.
# Keep the .p12 private and reuse it for every release: a new certificate resets everyone's Accessibility permission once.
set -euo pipefail
OUT="${1:-$HOME/HeyHumanlySigning}"; mkdir -p "$OUT"; chmod 700 "$OUT"; cd "$OUT"
[ -e signing.p12 ] && { echo "signing.p12 already exists in $OUT; reuse it." >&2; exit 1; }
cat > cert.cnf <<'CNF'
[req]
distinguished_name=dn
prompt=no
x509_extensions=ext
[dn]
CN=HeyHumanly Release
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 7300 -config cert.cnf 2>/dev/null
PASS="$(openssl rand -hex 24)"
openssl pkcs12 -export -inkey key.pem -in cert.pem -out signing.p12 -passout "pass:$PASS" -legacy 2>/dev/null \
  || openssl pkcs12 -export -inkey key.pem -in cert.pem -out signing.p12 -passout "pass:$PASS"
rm -f key.pem cert.cnf; chmod 600 signing.p12
echo "$PASS" > signing.p12.password; chmod 600 signing.p12.password
echo "Created $OUT/signing.p12. Add these repository secrets (Settings > Secrets and variables > Actions):"
echo "  SIGNING_CERT_P12       = output of: base64 -i '$OUT/signing.p12' | pbcopy"
echo "  SIGNING_CERT_PASSWORD  = contents of $OUT/signing.p12.password"
