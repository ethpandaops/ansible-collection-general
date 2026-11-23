#!/bin/sh
# install.sh [--check] [<version>]: installs or updates the upgradoor agent on
# this host from a signed release (version vX.Y.Z or latest). Downloads and
# verifies the manifest, installs the host binary if it changed, creates the
# user, directories and host key. Never starts the agent. --check changes
# nothing and reports what would change. Prints one JSON line:
#   {"changed", "version", "image_digest", "public_key", "cert_needed"}
# Settings come from UPGRADOOR_* variables (see below).
set -eu
umask 022
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LC_ALL=C
export PATH LC_ALL

check=0
if [ "${1:-}" = --check ]; then
    check=1
    shift
fi
version=${1:-latest}

lib=$(cd "$(dirname "$0")" && pwd)
releases=${UPGRADOOR_RELEASES_URL:-https://github.com/ethpandaops/upgradoor/releases}
network=${UPGRADOOR_NETWORK:-}
hostname=${UPGRADOOR_HOSTNAME:-}
signer=${UPGRADOOR_SIGNER_PUBLIC_KEY:-}
user=${UPGRADOOR_USER:-upgradoor}
group=${UPGRADOOR_GROUP:-upgradoor}
docker_group=${UPGRADOOR_DOCKER_GROUP:-docker}
entry=${UPGRADOOR_ENTRY_USER:-devops}
config_dir=${UPGRADOOR_CONFIG_DIR:-/etc/upgradoor}
key_file=${UPGRADOOR_KEY_FILE:-$config_dir/host.key}
cert_file=${UPGRADOOR_CERT_FILE:-$config_dir/host.crt}
state_dir=${UPGRADOOR_STATE_DIR:-/data/upgradoor}
# An empty overrides file: overrides are off, no directory and no link.
overrides_dir=${UPGRADOOR_OVERRIDES_DIR:-$config_dir/overrides}
overrides_file=${UPGRADOOR_OVERRIDES_FILE-$overrides_dir/overrides.yaml}
overrides_link=${UPGRADOOR_OVERRIDES_LINK-/home/$entry/overrides.yaml}
binary=${UPGRADOOR_BINARY:-/usr/local/bin/upgradoor}
seq_file=${UPGRADOOR_SEQ_FILE:-$config_dir/release-seq}
# Pull credentials the agent may read: a copy of root's docker config. Empty: none.
auth_source=${UPGRADOOR_REGISTRY_AUTH_SOURCE-/root/.docker/config.json}
auth_file=${UPGRADOOR_REGISTRY_AUTH_FILE-$config_dir/registry-auth.json}
image_repo=ghcr.io/ethpandaops/upgradoor

changed=false
work=""

die() {
    printf 'upgradoor install: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    [ -z "$work" ] || rm -rf -- "$work"
}
trap cleanup EXIT

# Runs a command that changes the host and marks the run changed.
apply() {
    changed=true
    if [ "$check" = 0 ]; then
        "$@" </dev/null >/dev/null
    fi
}

if [ -z "$network" ] || [ -z "$hostname" ] || [ -z "$signer" ]; then
    die "UPGRADOOR_NETWORK, UPGRADOOR_HOSTNAME and UPGRADOOR_SIGNER_PUBLIC_KEY are required"
fi
[ "$(id -u)" = 0 ] || die "must run as root"

case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) die "unsupported architecture $(uname -m)" ;;
esac

# Tools: curl and ssh-keygen for the release.
missing=""
command -v curl >/dev/null || missing="$missing curl"
command -v ssh-keygen >/dev/null || missing="$missing openssh-client"
if [ -n "$missing" ]; then
    # shellcheck disable=SC2086
    apply env DEBIAN_FRONTEND=noninteractive apt-get install -y -o DPkg::Lock::Timeout=300 $missing ||
        die "cannot install$missing"
fi

# Users and groups.
for g in "$group" "$docker_group"; do
    getent group "$g" >/dev/null || apply groupadd --system "$g"
done
if ! getent passwd "$user" >/dev/null; then
    apply useradd --system --gid "$group" --groups "$docker_group" --home-dir "$state_dir" \
        --no-create-home --shell /usr/sbin/nologin "$user"
elif ! id -Gn "$user" | tr ' ' '\n' | grep -qx -- "$docker_group"; then
    apply usermod --append --groups "$docker_group" "$user"
fi
if id "$entry" >/dev/null 2>&1 && ! id -Gn "$entry" | tr ' ' '\n' | grep -qx -- "$group"; then
    apply usermod --append --groups "$group" "$entry"
fi

# dir <path> <owner:group> <mode>
dir() {
    if [ ! -d "$1" ]; then
        apply mkdir -p -- "$1"
    elif [ "$(stat -c '%U:%G:%a' -- "$1")" = "$2:$(printf '%s' "$3" | sed 's/^0*//')" ]; then
        return
    fi
    apply chown "$2" -- "$1"
    apply chmod "$3" -- "$1"
}
dir "$config_dir" "root:$group" 0750
dir "$state_dir" "$user:$group" 0700
# setgid: files of the agent and the entry user share the group.
[ -z "$overrides_file" ] || dir "$overrides_dir" "$user:$group" 2775

# Release: the signed manifest names the seq, the image and the binaries.
if [ "$version" = latest ]; then
    base=$releases/latest/download
elif printf '%s' "$version" | grep -Eqx 'v(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})'; then
    base=$releases/download/$version
else
    die "version must be latest or a release tag vX.Y.Z, got '$version'"
fi

work=$(mktemp -d)
fetch() {
    curl -fsSL --retry 3 --max-time 300 -o "$2" "$1" || die "cannot download $1"
}
fetch "$base/upgradoor-manifest.txt" "$work/manifest"
fetch "$base/upgradoor-manifest.txt.sig" "$work/manifest.sig"
ssh-keygen -Y verify -f "$lib/allowed_signers" -I upgradoor-release -n upgradoor-release \
    -s "$work/manifest.sig" <"$work/manifest" >"$work/verify" 2>&1 ||
    die "the signature of $base/upgradoor-manifest.txt does not verify: $(cat "$work/verify")"

# Canonical form: sorted LF lines '<artifact> <seq> <name> <sha256>', one seq,
# exactly the image and both binaries of both platforms.
m=$work/manifest
line_re='(image|upgradoor|upgradoor-controller) [1-9][0-9]* [a-z0-9/._-]+ [0-9a-f]{64}'
if [ "$(tail -c 1 "$m" | od -An -c | tr -d ' ')" != '\n' ] || grep -q "$(printf '\r')" "$m" ||
    grep -Evxq "$line_re" "$m" || ! sort -c "$m" 2>/dev/null ||
    [ "$(cut -d ' ' -f 2 "$m" | sort -u | wc -l)" != 1 ] ||
    [ "$(cut -d ' ' -f 1,3 "$m" | tr '\n' ,)" != "image $image_repo,upgradoor linux-amd64,upgradoor linux-arm64,upgradoor-controller linux-amd64,upgradoor-controller linux-arm64," ]; then
    die "the manifest of $version is not canonical"
fi
seq=$(head -n 1 "$m" | cut -d ' ' -f 2)
release=v$((seq / 1000000)).$((seq / 1000 % 1000)).$((seq % 1000))
if [ "$version" != latest ] && [ "$version" != "$release" ]; then
    die "the manifest of $version carries seq $seq ($release)"
fi
image_digest=sha256:$(grep '^image ' "$m" | cut -d ' ' -f 4)
sha=$(grep "^upgradoor $seq linux-$arch " "$m" | cut -d ' ' -f 4)

# Binary: installed atomically when it differs, never a lower seq.
if [ -f "$seq_file" ]; then
    installed=$(cut -d ' ' -f 1 "$seq_file")
    case "$installed" in '' | *[!0-9]*) die "$seq_file must hold '<seq> <version>'" ;; esac
    [ "$seq" -ge "$installed" ] ||
        die "refusing a downgrade from $(cat "$seq_file") to $release; remove $seq_file to allow it"
fi
current=1
if ! [ -f "$binary" ] || [ "$(sha256sum <"$binary" | cut -c 1-64)" != "$sha" ]; then
    current=0
    changed=true
    if [ "$check" = 0 ]; then
        fetch "$releases/download/$release/upgradoor-linux-$arch" "$work/upgradoor"
        got=$(sha256sum <"$work/upgradoor" | cut -c 1-64)
        [ "$got" = "$sha" ] || die "upgradoor-linux-$arch of $release has sha256 $got, the manifest lists $sha"
        tmp=$(mktemp "$(dirname "$binary")/.upgradoor.XXXXXX")
        cp -- "$work/upgradoor" "$tmp"
        chmod 0755 -- "$tmp"
        mv -f -- "$tmp" "$binary"
        current=1
    fi
fi
if [ "$(cat "$seq_file" 2>/dev/null || true)" != "$seq $release" ]; then
    changed=true
    [ "$check" = 1 ] || printf '%s %s\n' "$seq" "$release" >"$seq_file"
fi

# Host key and certificate; in check mode only with the release installed.
public_key=""
cert_needed=true
[ -f "$key_file" ] || changed=true
if [ "$check" = 0 ] || { [ "$current" = 1 ] && [ -f "$key_file" ]; }; then
    public_key=$("$binary" key --path "$key_file") || die "upgradoor key failed"
fi
if [ -n "$public_key" ] && [ -f "$cert_file" ] &&
    certified=$("$binary" verify-cert --network "$network" --signer-public-key "$signer" <"$cert_file" 2>/dev/null) &&
    [ "$certified" = "{\"hostname\":\"$hostname\",\"network\":\"$network\",\"publicKey\":\"$public_key\"}" ]; then
    cert_needed=false
fi

# Registry credentials: kept in step with the source; without one, anonymous pulls.
if [ -n "$auth_file" ]; then
    if [ -n "$auth_source" ] && [ -f "$auth_source" ]; then
        if ! cmp -s -- "$auth_source" "$auth_file" ||
            [ "$(stat -c '%U:%G:%a' -- "$auth_file")" != "root:$group:640" ]; then
            apply install -o root -g "$group" -m 0640 -- "$auth_source" "$auth_file"
        fi
    elif [ -e "$auth_file" ]; then
        apply rm -f -- "$auth_file"
    fi
fi

# Overrides: the entry user's link; a regular file there becomes the file.
if [ -n "$overrides_file" ] && [ -n "$overrides_link" ]; then
    if [ -f "$overrides_link" ] && [ ! -L "$overrides_link" ] && [ ! -e "$overrides_file" ]; then
        apply mv -T -- "$overrides_link" "$overrides_file"
        apply chown "$user:$group" -- "$overrides_file"
        apply chmod 0664 -- "$overrides_file"
    fi
    if id "$entry" >/dev/null 2>&1 && { [ "$(readlink -- "$overrides_link" || true)" != "$overrides_file" ] ||
        [ "$(stat -c %U -- "$overrides_link")" != "$entry" ]; }; then
        apply ln -sfT -- "$overrides_file" "$overrides_link"
        apply chown -h "$entry" -- "$overrides_link"
    fi
fi
printf '{"changed": %s, "version": "%s", "image_digest": "%s", "public_key": "%s", "cert_needed": %s}\n' \
    "$changed" "$release" "$image_digest" "$public_key" "$cert_needed"
