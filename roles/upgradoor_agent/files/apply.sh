#!/bin/sh
# Applies the upgradoor agent bundle read from stdin: one directive per line,
# fields separated by single spaces, "-" for an empty field. Prints one JSON
# object on stdout and only its own messages on stderr; exits 1 on a refusal.
# UPGRADOOR_CHECK=True changes nothing and reports what would change;
# UPGRADOOR_RESTART=True restarts the agent even without a change here.
set -eu
umask 077
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LC_ALL=C
export PATH LC_ALL

check=0
restart=0
case "${UPGRADOOR_CHECK:-}" in True | true | 1) check=1 ;; esac
case "${UPGRADOOR_RESTART:-}" in True | true | 1) restart=1 ;; esac

changes=""
reload=0
user_changed=""
tmp=""
finished=0

json_string() {
    printf '"%s"' "$(printf '%s' "$1" | tr '\n\t\r' '   ' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

finish() {
    finished=1
    list=""
    if [ -n "$changes" ]; then
        list="$(printf '%s\n' "$changes" | while IFS= read -r line; do printf '%s, ' "$(json_string "$line")"; done)"
        list="${list%, }"
    fi

    changed=false
    [ -n "$changes" ] && changed=true

    printf '{"changed": %s, "failed": %s, "msg": %s, "changes": [%s]}\n' \
        "$changed" "$1" "$(json_string "$2")" "$list"
}

die() {
    printf 'upgradoor apply: %s\n' "$1" >&2
    finish true "$1"
    exit 1
}

on_exit() {
    rc=$?
    if [ -n "$tmp" ]; then
        rm -f -- "$tmp"
    fi

    if [ "$finished" = 0 ]; then
        printf 'upgradoor apply: unexpected error (exit %s)\n' "$rc" >&2
        finish true "unexpected error (exit $rc), see stderr"
    fi
}
trap on_exit EXIT

note() {
    changes="$changes${changes:+
}$1"
}

# Runs a command that changes the host, unless checking.
run() {
    if [ "$check" = 0 ]; then
        "$@" </dev/null >/dev/null
    fi
}

field() {
    if [ "$1" = - ]; then
        printf ''
    else
        printf '%s' "$1"
    fi
}

mode_of() {
    m="$(printf '%s' "$1" | sed 's/^0*//')"
    printf '%s' "${m:-0}"
}

# Sets owner, group and mode; touched=1 when something changed. Never called
# as a condition: set -e does not apply there.
attrs() {
    touched=0
    if [ "$(stat -c '%U:%G:%a' -- "$1")" != "$2:$3:$(mode_of "$4")" ]; then
        run chown "$2:$3" -- "$1"
        run chmod "$4" -- "$1"
        touched=1
    fi
}

sha256_of() {
    sha256sum -- "$1" | cut -c1-64
}

# fail <base64 message>
d_fail() {
    die "$(printf '%s' "$1" | base64 -d)"
}

# release <version> <seq> <sha256> <arch> <url> <install dir> <binary> <seq file> <allow downgrade> <python>
d_release() {
    version=$1 seq=$2 sha=$3 arch=$4 url=$5 install_dir=$6 binary=$7 seq_file=$8 allow_downgrade=$9
    shift 9
    python=$1

    if [ -f "$binary" ] && [ "$(sha256_of "$binary")" = "$sha" ]; then
        return
    fi

    bin_dir="$(dirname -- "$binary")"
    if [ -d "$install_dir" ] && [ -d "$bin_dir" ]; then
        same=0
        [ "$(stat -L -c '%d:%i' -- "$install_dir")" = "$(stat -L -c '%d:%i' -- "$bin_dir")" ] && same=1
    else
        same=0
        [ "$(realpath -ms -- "$install_dir")" = "$(realpath -ms -- "$bin_dir")" ] && same=1
    fi
    if [ "$same" = 1 ]; then
        die "upgradoor_agent_install_dir ($install_dir) must not be the directory of upgradoor_agent_binary_path ($binary)."
    fi

    if [ -e "$seq_file" ] || [ -L "$seq_file" ]; then
        if ! { [ -f "$seq_file" ] && [ ! -L "$seq_file" ] && [ "$(stat -c %s -- "$seq_file")" -le 64 ] \
            && [ "$(wc -l <"$seq_file")" -eq 1 ] && [ "$(tail -c 1 -- "$seq_file" | od -An -c | tr -d ' ')" = '\n' ] \
            && grep -Eqx '[0-9]+ v[^[:space:]]+' -- "$seq_file"; }; then
            die "$seq_file must be a regular file with one line '<seq> <version>' (e.g. '1002003 v1.2.3'); remove it to install without a downgrade floor."
        fi

        installed="$(cut -d ' ' -f 1 <"$seq_file")"
        if [ "$allow_downgrade" != 1 ] && ! [ "$seq" -ge "$installed" ] 2>/dev/null; then
            die "refusing a downgrade from '$(cat -- "$seq_file")' to upgradoor $version; set upgradoor_agent_allow_downgrade=true to allow it."
        fi
    fi

    download="$install_dir/upgradoor-$version-linux-$arch"
    if [ "$check" = 1 ]; then
        note "binary $binary: install $version (sha256 $sha) from $url"
        return
    fi

    if [ ! -d "$install_dir" ]; then
        (umask 022 && mkdir -p -- "$install_dir")
    fi
    attrs "$install_dir" root root 0700

    if ! { [ -f "$download" ] && [ "$(sha256_of "$download")" = "$sha" ]; }; then
        tmp="$download.part"
        tries=0
        until "$python" -c 'import shutil, sys, urllib.request
with urllib.request.urlopen(sys.argv[1], timeout=120) as r, open(sys.argv[2], "wb") as f:
    shutil.copyfileobj(r, f)' "$url" "$tmp" </dev/null >/dev/null; do
            tries=$((tries + 1))
            [ "$tries" -lt 3 ] || die "cannot download $url"
            sleep 5
        done

        got="$(sha256_of "$tmp")"
        if [ "$got" != "$sha" ]; then
            die "the download of $url has sha256 $got, the verified manifest lists $sha"
        fi

        chmod 0755 -- "$tmp"
        mv -f -- "$tmp" "$download"
        tmp=""
    fi

    tmp="$(mktemp "$bin_dir/.upgradoor-apply.XXXXXX")"
    cp -- "$download" "$tmp"
    chown root:root -- "$tmp"
    chmod 0755 -- "$tmp"
    mv -f -- "$tmp" "$binary"
    tmp=""
    note "binary $binary: installed $version"
    restart=1

    for old in "$install_dir"/upgradoor-v*-linux-*; do
        if [ -f "$old" ] && [ "$old" != "$download" ]; then
            rm -f -- "$old"
        fi
    done

    (umask 022 && mkdir -p -- "$(dirname -- "$seq_file")")
    write_file "$seq_file" root root 0644 - "$(printf '%s %s\n' "$seq" "$version" | base64 -w 0)"
}

# group <name>
d_group() {
    if ! getent group "$1" >/dev/null; then
        run groupadd --system "$1"
        note "group $1"
    fi
}

# user <name> <group> <supplementary groups, comma separated> <home> <shell>
d_user() {
    name=$1 group=$2 groups=$3 home=$4 shell=$5

    if ! entry="$(getent passwd "$name")"; then
        run useradd --system --gid "$group" --groups "$groups" --home-dir "$home" --no-create-home --shell "$shell" "$name"
        note "user $name"
        user_changed="$name:$group:$home"
        restart=1
        return
    fi

    if [ "$(id -gn "$name")" != "$group" ] || [ "$(printf '%s' "$entry" | cut -d: -f6)" != "$home" ] \
        || [ "$(printf '%s' "$entry" | cut -d: -f7)" != "$shell" ]; then
        run usermod --gid "$group" --home "$home" --shell "$shell" "$name"
        note "user $name"
        user_changed="$name:$group:$home"
        restart=1
    fi

    for g in $(printf '%s' "$groups" | tr ',' ' '); do
        if ! id -Gn "$name" | tr ' ' '\n' | grep -qx -- "$g"; then
            run usermod --append --groups "$g" "$name"
            note "user $name: group $g"
            user_changed="$name:$group:$home"
            restart=1
        fi
    done
}

# member <user> <group>: only an existing user
d_member() {
    if id "$1" >/dev/null 2>&1 && ! id -Gn "$1" | tr ' ' '\n' | grep -qx -- "$2"; then
        run usermod --append --groups "$2" "$1"
        note "user $1: group $2"
    fi
}

# dir <path> <owner> <group> <mode>
d_dir() {
    if [ -L "$1" ] || { [ -e "$1" ] && [ ! -d "$1" ]; }; then
        die "$1 is not a directory"
    fi

    if [ ! -d "$1" ]; then
        note "directory $1"
        if [ "$check" = 0 ]; then
            (umask 022 && mkdir -p -- "$1")
            attrs "$1" "$2" "$3" "$4"
        fi
        return
    fi

    attrs "$1" "$2" "$3" "$4"
    if [ "$touched" = 1 ]; then
        note "directory $1: owner or mode"
    fi
}

# Writes base64 content atomically when it differs; touched=1 when it changed.
# write_file <path> <owner> <group> <mode> <validate command> <base64>
write_file() {
    path=$1 owner=$2 group=$3 mode=$4 validate=$5 content=$6

    if [ -f "$path" ] && [ ! -L "$path" ] && printf '%s' "$content" | base64 -d | cmp -s - "$path"; then
        attrs "$path" "$owner" "$group" "$mode"
        if [ "$touched" = 1 ]; then
            note "$path: owner or mode"
        fi
        return
    fi

    note "$path"
    touched=1
    if [ "$check" = 1 ]; then
        return
    fi

    tmp="$(mktemp "$(dirname -- "$path")/.upgradoor-apply.XXXXXX")"
    printf '%s' "$content" | base64 -d >"$tmp"
    chown "$owner:$group" -- "$tmp"
    chmod "$mode" -- "$tmp"
    if [ "$validate" != - ] && ! "$validate" -cf "$tmp" </dev/null >/dev/null; then
        die "$path: $validate refused the new content"
    fi
    mv -f -- "$tmp" "$path"
    tmp=""
}

# file <path> <owner> <group> <mode> <flags: restart,reload,visudo> <base64>
d_file() {
    validate=-
    case ",$5," in *,visudo,*) validate=visudo ;; esac

    write_file "$1" "$2" "$3" "$4" "$validate" "$6"
    if [ "$touched" = 1 ]; then
        case ",$5," in *,restart,*) restart=1 ;; esac
        case ",$5," in *,reload,*) reload=1 ;; esac
    fi
}

# copy <source> <destination> <owner> <group> <mode>: removes the destination without a regular source
d_copy() {
    if [ -f "$1" ] && [ ! -L "$1" ]; then
        write_file "$2" "$3" "$4" "$5" - "$(base64 -w 0 -- "$1")"
    elif [ -e "$2" ] || [ -L "$2" ]; then
        run rm -f -- "$2"
        note "$2: removed"
    fi
}

# acl <file> <user>: lets the user pass through the file's directory
d_acl() {
    dir="$(dirname -- "$1")"
    if [ ! -d "$dir" ]; then
        return
    fi

    if ! command -v setfacl >/dev/null; then
        note "package acl"
        if [ "$check" = 1 ]; then
            note "$dir: acl for $2"
            return
        fi
        DEBIAN_FRONTEND=noninteractive apt-get install -y -o DPkg::Lock::Timeout=300 acl </dev/null >/dev/null \
            || die "cannot install the acl package"
    fi

    if [ "$(getfacl -cp -- "$dir" 2>/dev/null | sed -n "s/^user:$2:\\(...\\).*/\\1/p")" != "--x" ]; then
        run setfacl -m "u:$2:x" -- "$dir"
        note "$dir: acl for $2"
    fi
}

# overrides <file> <link> <entry user> <owner> <group>
d_overrides() {
    file=$1 link=$2 entry=$3

    if [ -z "$link" ]; then
        return
    fi

    # A regular file at the link is the file people wrote before there was one.
    if [ -f "$link" ] && [ ! -L "$link" ] && [ ! -e "$file" ] && [ ! -L "$file" ]; then
        run mv -T -- "$link" "$file"
        run chown "$4:$5" -- "$file"
        run chmod 0664 -- "$file"
        note "$link: moved to $file"
    fi

    if ! id "$entry" >/dev/null 2>&1; then
        return
    fi

    if [ ! -L "$link" ] || [ "$(readlink -- "$link")" != "$file" ]; then
        run ln -sfT -- "$file" "$link"
        run chown -h "$entry" -- "$link"
        note "$link: link"
    elif [ "$(stat -c %U -- "$link")" != "$entry" ]; then
        run chown -h "$entry" -- "$link"
        note "$link: owner"
    fi
}

# service <name> <enabled: 0|1> <state: started|stopped|restarted>
d_service() {
    name=$1 enabled=$2 state=$3

    # A recreated user may have another uid.
    if [ -n "$user_changed" ]; then
        home="${user_changed#*:*:}"
        owner="${user_changed%%:*}"
        group="${user_changed#*:}"
        group="${group%%:*}"
        if [ -d "$home" ]; then
            run chown -R "$owner:$group" -- "$home"
        fi
    fi

    if [ "$reload" = 1 ]; then
        run systemctl daemon-reload
    fi

    current="$(systemctl is-enabled "$name" 2>/dev/null || true)"
    if [ "$enabled" = 1 ] && [ "$current" != enabled ]; then
        run systemctl enable "$name"
        note "service $name: enabled"
    elif [ "$enabled" = 0 ] && [ "$current" = enabled ]; then
        run systemctl disable "$name"
        note "service $name: disabled"
    fi

    case "$state" in
        started)
            if [ "$restart" = 1 ]; then
                run systemctl restart "$name"
                note "service $name: restarted"
            elif ! systemctl is-active --quiet "$name"; then
                run systemctl start "$name"
                note "service $name: started"
            fi
            ;;
        restarted)
            run systemctl restart "$name"
            note "service $name: restarted"
            ;;
        stopped)
            if systemctl is-active --quiet "$name"; then
                run systemctl stop "$name"
                note "service $name: stopped"
            fi
            ;;
        *) die "unknown service state: $state" ;;
    esac
}

# init <binary> <overrides file> <socket>: the running agent writes a missing
# overrides file (generated block only).
d_init() {
    if [ -e "$2" ] || [ -L "$2" ]; then
        return
    fi

    note "$2: written by the agent"
    if [ "$check" = 1 ]; then
        return
    fi

    tries=0
    until "$1" init-overrides --socket "$3" </dev/null >/dev/null 2>&1; do
        tries=$((tries + 1))
        [ "$tries" -lt 30 ] || die "the agent did not write $2 (is it running? see journalctl -u upgradoor-agent)"
        sleep 1
    done
}

exec 3<&0 </dev/null

while IFS=' ' read -r kind a b c d e f g h i j <&3; do
    case "$kind" in
        fail) d_fail "$a" ;;
        release) d_release "$a" "$b" "$c" "$d" "$e" "$f" "$g" "$h" "$i" "$j" ;;
        group) d_group "$a" ;;
        user) d_user "$a" "$b" "$c" "$d" "$e" ;;
        member) d_member "$a" "$b" ;;
        dir) d_dir "$a" "$b" "$c" "$d" ;;
        file) d_file "$a" "$b" "$c" "$d" "$e" "$f" ;;
        copy) d_copy "$a" "$b" "$c" "$d" "$e" ;;
        acl) d_acl "$a" "$b" ;;
        overrides) d_overrides "$a" "$(field "$b")" "$c" "$d" "$e" ;;
        service) d_service "$a" "$b" "$c" ;;
        init) d_init "$a" "$b" "$c" ;;
        '') ;;
        *) die "unknown directive: $kind" ;;
    esac
done

finish false ""
