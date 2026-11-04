#!/bin/sh
# Stream a snapshot into tar, resuming by byte offset.
#
# A single connection cannot carry a mainnet-scale snapshot: the snapshot server
# closes a stream roughly every 40-60 GB, and geth mainnet is 1.16 TB
# compressed. `wget -O - | tar`, which this replaces, cannot resume at all --
# wget cannot seek stdout, so a retry re-sends the body from byte 0 into a tar
# that has already consumed bytes. Nothing but the extracted datadir ever
# touches disk, so no room is needed for a tarball beside it.
#
# Mirrors ethpandaops/ethereum-package src/network_launcher/shadowfork.star.
set -e

[ -n "${URL}" ] || { echo "URL is not set"; exit 1; }

TOTAL=$(curl -sfIL "${URL}" | tr -d '\r' | awk 'tolower($1)=="content-length:"{n=$2} END{print n}')
[ -n "${TOTAL}" ] || { echo "cannot read the snapshot size from ${URL}"; exit 1; }
echo "snapshot is ${TOTAL} bytes"

stream() {
  off=0
  n=0
  unranged=0
  while [ "${off}" -lt "${TOTAL}" ]; do
    n=$((n + 1))
    [ "${n}" -gt 500 ] && { echo "giving up at byte ${off} after ${n} attempts" >&2; return 1; }
    echo "fetching from byte ${off} (attempt ${n})" >&2
    rc=0
    # curl only times out the CONNECT, so a stream that stalls without closing
    # would hang forever; under 1 KB/s for 120 s it exits 28 and the loop resumes.
    curl -sfL --connect-timeout 20 --speed-limit 1024 --speed-time 120 \
      -C "${off}" -w '%{stderr}%{size_download}' "${URL}" 2>/tmp/got || rc=$?
    got=$(cat /tmp/got)
    # A missing count means curl died by signal mid-transfer: the bytes it already
    # handed to tar are unaccounted for, so resuming at ${off} would replay them.
    case "${got}" in
      ''|*[!0-9]*) echo "curl exited ${rc} without a byte count ('${got}'); refusing to resume" >&2; return 1 ;;
    esac
    off=$((off + got))
    if [ "${rc}" -eq 0 ]; then
      unranged=0
    elif [ "${rc}" -eq 33 ]; then
      # A ranged request came back as a plain 200 and curl wrote no body, so the
      # same offset is retried. The public snapshot server's edge does this
      # transiently, about once in 40 resumes; a server with no Range support
      # does it every time, and looping there only delays a certain failure.
      unranged=$((unranged + 1))
      [ "${unranged}" -ge 10 ] && {
        echo "server answered ${unranged} ranged requests with 200: it does not support Range, so a dropped connection cannot be resumed" >&2
        return 1
      }
    else
      unranged=0
      echo "stream broke (curl ${rc}) at byte ${off}, resuming" >&2
      sleep 5
    fi
  done
}

stream | tar -I zstd -xf - -C /data
