#!/bin/sh
set -eu
while true; do
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' INT TERM EXIT
  echo "Fetching ${WILDCARD_CERT_URL}"
  if curl -fsS -o "${TMP}/bundle.enc" "${WILDCARD_CERT_URL}"; then
    # decrypt (matches issuer's openssl enc -aes-256-cbc -salt)
    openssl enc -d -aes-256-cbc -pass env:WILDCARD_CERT_PSK \
      -in "${TMP}/bundle.enc" -out "${TMP}/bundle.tar.gz"

    EXTD="$(mktemp -d)"
    tar -xzf "${TMP}/bundle.tar.gz" -C "${EXTD}"

    NEWCRT="${EXTD}/${WILDCARD_CERT_NAME}.crt"
    NEWKEY="${EXTD}/${WILDCARD_CERT_NAME}.key"
    NEWCHN="${EXTD}/${WILDCARD_CERT_NAME}.chain.pem"

    CURCRT="/etc/nginx/certs/${WILDCARD_CERT_NAME}.crt"
    CURKEY="/etc/nginx/certs/${WILDCARD_CERT_NAME}.key"
    CURCHN="/etc/nginx/certs/${WILDCARD_CERT_NAME}.chain.pem"

    newcrt_hash="$(sha256sum "$NEWCRT" | awk '{print $1}')"
    newkey_hash="$(sha256sum "$NEWKEY" | awk '{print $1}')"
    newchn_hash="$(sha256sum "$NEWCHN" 2>/dev/null | awk '{print $1}' || true)"

    curcrt_hash="$(sha256sum "$CURCRT" 2>/dev/null | awk '{print $1}' || true)"
    curkey_hash="$(sha256sum "$CURKEY" 2>/dev/null | awk '{print $1}' || true)"
    curchn_hash="$(sha256sum "$CURCHN" 2>/dev/null | awk '{print $1}' || true)"

    if [ "$newcrt_hash" = "$curcrt_hash" ] && \
      [ "$newkey_hash" = "$curkey_hash" ] && \
      [ "$newchn_hash" = "$curchn_hash" ]; then
      echo "Cert/key/chain unchanged; no reload."
    else
      echo "Updating cert/key/chain; reloading nginx-proxy."
      chown "${CERT_UID}:${CERT_GID}" "$NEWCRT" "$NEWKEY" "$NEWCHN" 2>/dev/null || true
      chmod 0644 "$NEWCRT" "$NEWCHN"
      chmod 0600 "$NEWKEY"

      mv -f "$NEWCRT" "$CURCRT"
      mv -f "$NEWKEY" "$CURKEY"
      [ -s "$NEWCHN" ] && mv -f "$NEWCHN" "$CURCHN" || true

      if command -v docker >/dev/null 2>&1; then
        docker kill -s HUP "${NGINX_PROXY_NAME}" >/dev/null 2>&1 || true
      fi
    fi
  fi
  sleep "${FETCH_INTERVAL}"
done