#!/usr/bin/env bash
# Linux native test ownership: no upstream test or service command is rewritten.
set -Eeuo pipefail
phase=host; original_parent=$PPID; guarded_parent=
case "${1-}" in
    --internal) phase=outer; shift;;
    --inner) phase=inner; shift;;
    --parent-guarded) guarded_parent=${2-}; shift 2;;
esac
cli=("$@")
work= prefix= domain= bwrap= unshare= ip=
native_roots=()
ssh=/usr/bin/ssh; sshd=/usr/sbin/sshd; keygen=/usr/bin/ssh-keygen; nsenter=/usr/bin/nsenter
xvfb=/usr/bin/Xvfb; xvfb_run=/usr/bin/xvfb-run; xauth=/usr/bin/xauth
setpriv=/usr/bin/setpriv
while (($#)); do
    case "$1" in
        --work-root) work=$2; shift 2;;
        --candidate-prefix) prefix=$2; shift 2;;
        --domain) domain=$2; shift 2;;
        --bwrap) bwrap=$2; shift 2;;
        --unshare) unshare=$2; shift 2;;
        --ip) ip=$2; shift 2;;
        --ssh) ssh=$2; shift 2;;
        --sshd) sshd=$2; shift 2;;
        --ssh-keygen) keygen=$2; shift 2;;
        --nsenter) nsenter=$2; shift 2;;
        --native-root) native_roots+=("$2"); shift 2;;
        --xvfb) xvfb=$2; shift 2;;
        --xvfb-run) xvfb_run=$2; shift 2;;
        --xauth) xauth=$2; shift 2;;
        --setpriv) setpriv=$2; shift 2;;
        --) shift; break;;
        *) printf 'Unknown Linux launcher option: %s\n' "$1" >&2; exit 2;;
    esac
done
(($#)) && [[ $work = /* && $prefix = /* && $bwrap = /* && $unshare = /* && $ip = /* ]] || exit 2
# The private network owns the native default; a global port environment
# override would take precedence over original suites' explicit alternate ports.
unset ERL_EPMD_PORT ERL_EPMD_ADDRESS
unset ERL_FLAGS ERL_AFLAGS ERL_ZFLAGS ERL_LIBS ERL_COMPILER_OPTIONS ERL_EXTREME_TESTING
unset LD_PRELOAD LD_AUDIT LD_LIBRARY_PATH
unset BASH_ENV ENV ZDOTDIR
gui=no
case "$domain" in wx|et|debugger|observer|reltool) gui=yes;; esac
if [[ $phase != inner || $gui = no ]]; then unset DISPLAY XAUTHORITY; fi
command=("$@")
self=$(/usr/bin/readlink -f "${BASH_SOURCE[0]}")
workspace=$(/usr/bin/readlink -f "${self%/*}/../../../..")
[[ $work = "$workspace/tmp/"* && $work = "$(/usr/bin/readlink -m "$work")" ]] || { printf 'Work root must be a canonical path below %s/tmp\n' "$workspace" >&2; exit 2; }
for input in "$prefix" "${self%/*}/../../.."; do
    input=$(/usr/bin/readlink -m "$input")
    [[ $input != "$work" && $input != "$work/"* && $work != "$input/"* ]] || { printf 'Work root overlaps a selected input: %s\n' "$input" >&2; exit 2; }
done
for p in "${native_roots[@]}"; do
    [[ $p = /* && $p != / && -d $p && $p = "$(/usr/bin/readlink -f "$p")" && $p != "$work" && $p != "$work/"* && $work != "$p/"* ]] || { printf 'Invalid native root: %s\n' "$p" >&2; exit 2; }
    present=no
    for part in usr etc; do
        if [[ -e $p/$part || -L $p/$part ]]; then [[ -d $p/$part && ! -L $p/$part ]] || exit 2; present=yes; fi
    done
    [[ $present = yes ]] || exit 2
    for base in . usr usr/local; do
        for entry in "$p/$base"/{bin,sbin}/*; do
            name=${entry##*/}; name=${name,,}; name=${name%.exe}
            case "$name" in erl|erlc|escript|beam|beam.*|erlexec|epmd|ct_run|cerl|erl_call|erl_child_setup|run_erl|to_erl|dialyzer|typer|snmpc|start|start_erl|inet_gethost)
                printf 'Native root contains a VM command: %s\n' "$entry" >&2; exit 2;; esac
        done
        for entry in "$p/$base"/{lib,lib64}/{erlang,erlang-*}; do
            [[ ! -e $entry && ! -L $entry ]] || { printf 'Native root contains a VM payload: %s\n' "$entry" >&2; exit 2; }
        done
    done
    beam_file=$(/usr/bin/find "$p" -iname '*.beam' -print -quit) || exit 2
    [[ -z $beam_file ]] || { printf 'Native root contains a BEAM file: %s\n' "$beam_file" >&2; exit 2; }
done
namespaces() { local n; for n in pid net mnt user ipc uts; do printf '%s=%s\n' "$n" "$(/usr/bin/readlink /proc/self/ns/"$n")"; done; }
tool_hashes() { while IFS='=' read -r name path; do hash=$(/usr/bin/sha256sum "$path"); printf '%s=%s\n' "$name" "${hash%% *}"; done < "$OTP_CT_LINUX_ENVELOPE/selected-tools"; }
if [[ $phase = inner ]]; then
    namespaces > "$OTP_CT_LINUX_ENVELOPE/inner-namespaces"
    printf 'uid=%s\ngid=%s\n' "$(/usr/bin/id -u)" "$(/usr/bin/id -g)" > "$OTP_CT_LINUX_ENVELOPE/inner-account"
    /bin/cat /proc/self/mountinfo > "$OTP_CT_LINUX_ENVELOPE/inner-mountinfo"
    tool_hashes > "$OTP_CT_LINUX_ENVELOPE/effective-tool-sha256"
    printf 'display=%s\nxauthority=%s\n' "${DISPLAY-}" "${XAUTHORITY-}" > "$OTP_CT_LINUX_ENVELOPE/display"
    exec "${command[@]}"
fi
for p in "$work" "$prefix" "$self" "$bwrap" "$unshare" "$ip" "$ssh" "$sshd" "$keygen" "$nsenter" "$xvfb" "$xvfb_run" "$xauth" "$setpriv" "${native_roots[@]}"; do
    [[ $p != *$'\n'* && $p != *'"'* && $p != *"'"* ]] || exit 2
done
for p in "$bwrap" "$unshare" "$ip" "$setpriv"; do [[ $p = /* && -x $p ]] || { printf 'Missing tool: %s\n' "$p" >&2; exit 2; }; done
if [[ $phase = host ]]; then
    # Arm this same PID before owning children. Recheck the original parent
    # after exec so its death between capture and prctl cannot orphan a run.
    if [[ -z $guarded_parent ]]; then
        ((original_parent>1)) || { printf 'Orphaned Linux launcher\n' >&2; exit 143; }
        exec "$setpriv" --pdeathsig TERM -- "$BASH" "$self" --parent-guarded "$original_parent" "${cli[@]}"
    fi
    [[ $guarded_parent =~ ^[0-9]+$ && $PPID = "$guarded_parent" ]] && ((guarded_parent>1)) || { printf 'Linux launcher parent changed\n' >&2; exit 143; }
    mkdir -p -- "$work"
    work=$(/usr/bin/readlink -f "$work")
    export OTP_CT_LINUX_ENVELOPE="$work/.linux-envelope-$$-$RANDOM"
    mkdir -m 700 -- "$OTP_CT_LINUX_ENVELOPE"
    export OTP_CT_LINUX_UID="$(/usr/bin/id -u)" OTP_CT_LINUX_GID="$(/usr/bin/id -g)"
    IFS=: read -r _ _ _ _ _ OTP_CT_LINUX_PW_HOME _ < <(/usr/bin/getent passwd "$OTP_CT_LINUX_UID")
    export OTP_CT_LINUX_PW_HOME
    [[ $OTP_CT_LINUX_PW_HOME = /* ]] || exit 2
    namespaces > "$OTP_CT_LINUX_ENVELOPE/host-namespaces"
    /bin/cat /proc/sys/net/ipv4/ip_unprivileged_port_start > "$OTP_CT_LINUX_ENVELOPE/host-unprivileged-port-start"
    printf 'bwrap=%s\nunshare=%s\nip=%s\nsetpriv=%s\n' "$bwrap" "$unshare" "$ip" "$setpriv" > "$OTP_CT_LINUX_ENVELOPE/selected-tools"
    printf 'expected_parent_pid=%s\nrequested_death_signal=TERM\n' "$guarded_parent" > "$OTP_CT_LINUX_ENVELOPE/parent-lifecycle"
    for p in "$ssh" "$sshd" "$keygen" "$nsenter" "$xvfb" "$xvfb_run" "$xauth"; do [[ $p = /* && -x $p ]] || exit 2; done
    printf 'ssh=%s\nsshd=%s\nssh-keygen=%s\nnsenter=%s\n' "$ssh" "$sshd" "$keygen" "$nsenter" >> "$OTP_CT_LINUX_ENVELOPE/selected-tools"
    printf 'xvfb=%s\nxvfb-run=%s\nxauth=%s\n' "$xvfb" "$xvfb_run" "$xauth" >> "$OTP_CT_LINUX_ENVELOPE/selected-tools"
    tool_hashes > "$OTP_CT_LINUX_ENVELOPE/tool-sha256"
    : > "$OTP_CT_LINUX_ENVELOPE/native-roots"
    for p in "${native_roots[@]}"; do printf '%s\n' "$p" >> "$OTP_CT_LINUX_ENVELOPE/native-roots"; done
    mkdir -m 700 "$OTP_CT_LINUX_ENVELOPE/home" "$OTP_CT_LINUX_ENVELOPE/tmp" "$OTP_CT_LINUX_ENVELOPE/ssh-client"
    : > "$OTP_CT_LINUX_ENVELOPE/ssh_config"
    unset OTP_CT_LINUX_EPMD_CONFIG
    child=
    finish() {
        local status=$?
        trap - EXIT INT TERM
        if [[ -n $child ]]; then kill -KILL "$child" 2>/dev/null || true; wait "$child" 2>/dev/null || true; fi
        printf 'exit_status=%s\nnamespace_parent_reaped=yes\n' "$status" > "$OTP_CT_LINUX_ENVELOPE/status"
        exit "$status"
    }
    trap finish EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
    "$unshare" --user --map-root-user --mount --pid --fork --kill-child --mount-proc --net --ipc --uts "$BASH" "$self" --internal "${cli[@]}" &
    child=$!
    set +e; wait "$child"; status=$?; set -e; child=
    exit "$status"
fi
record=$OTP_CT_LINUX_ENVELOPE
namespaces > "$record/outer-namespaces"
"$ip" link set lo up
"$ip" -6 address replace ::1/128 dev lo
IFS= read -r hostname < /proc/sys/kernel/hostname
[[ $hostname =~ ^[a-zA-Z0-9._-]+$ ]] || exit 2
printf '127.0.0.1 localhost\n127.0.1.1 %s\n::1 localhost ip6-localhost ip6-loopback\n' "$hostname" > "$record/hosts-main"
common=(--unshare-user --uid "$OTP_CT_LINUX_UID" --gid "$OTP_CT_LINUX_GID" --unshare-pid --unshare-ipc --unshare-uts --die-with-parent --new-session
    --ro-bind / / --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --tmpfs "$OTP_CT_LINUX_PW_HOME")
for part in usr etc; do
    sources=()
    for p in "${native_roots[@]}"; do [[ ! -d $p/$part ]] || sources+=("$p/$part"); done
    if ((${#sources[@]})); then
        common+=(--overlay-src "/$part")
        for p in "${sources[@]}"; do common+=(--overlay-src "$p"); done
        common+=(--ro-overlay "/$part")
    fi
done
# Restore input paths read-only while hiding ambient SSH and shell startup files.
shopt -s dotglob nullglob
for entry in "$OTP_CT_LINUX_PW_HOME"/*; do
    case "${entry##*/}" in .ssh|.bashrc|.bash_profile|.bash_login|.profile|.zshrc|.zprofile|.zlogin|.zshenv|.kshrc|.mkshrc|.login|.cshrc|.tcshrc) continue;; esac
    if [[ -L $entry ]]; then common+=(--symlink "$(/usr/bin/readlink "$entry")" "$entry"); else common+=(--ro-bind "$entry" "$entry"); fi
done
shopt -u dotglob nullglob
common+=(--bind "$work" "$work" --chdir "$record"
    --ro-bind "$record/ssh-client" "$OTP_CT_LINUX_PW_HOME/.ssh" --ro-bind "$record/ssh_config" /etc/ssh/ssh_config
    --setenv HOME "$record/home" --setenv TMPDIR "$record/tmp" --unsetenv SSH_AUTH_SOCK --unsetenv SSH_AGENT_PID --cap-drop ALL)
if [[ $domain = ftp ]]; then
    # Original anonymous fixtures require this account even in launching-user mode.
    # Keep the host account database unchanged; the alias owns only this job.
    /usr/bin/awk -F: '$1 != "ftp"' /etc/passwd > "$record/passwd"
    /usr/bin/awk -F: '$1 != "ftp"' /etc/group > "$record/group"
    printf 'ftp:x:%s:%s:OTP test FTP:%s:/usr/sbin/nologin\n' "$OTP_CT_LINUX_UID" "$OTP_CT_LINUX_GID" "$record/home" >> "$record/passwd"
    printf 'ftp:x:%s:\n' "$OTP_CT_LINUX_GID" >> "$record/group"
    common+=(--ro-bind "$record/passwd" /etc/passwd --ro-bind "$record/group" /etc/group)
fi
peer= daemon=
cleanup() {
    local status=$?
    trap - EXIT INT TERM
    for p in "$daemon" "$peer"; do if [[ -n $p ]]; then kill "$p" 2>/dev/null || true; wait "$p" 2>/dev/null || true; fi; done
    printf 'exit_status=%s\nowned_services_reaped=yes\n' "$status" > "$record/outer-status"
    exit "$status"
}
trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
"$ip" link add ctl0 type veth peer name peer0
"$unshare" --net /bin/sh -c ': > "$1/peer-ready"; exec /bin/sleep infinity' sh "$record" &
peer=$!
for ((i=0;i<50;i++)); do [[ -f $record/peer-ready ]] && break; /bin/sleep 0.1; done
[[ -f $record/peer-ready ]]
"$ip" link set peer0 netns "$peer"
"$ip" address add 10.203.0.1/30 dev ctl0; "$ip" link set ctl0 up
"$ip" -6 address add fd42:203::1/126 dev ctl0 nodad
"$nsenter" -t "$peer" -n "$ip" link set lo up
"$nsenter" -t "$peer" -n "$ip" -6 address replace ::1/128 dev lo
"$nsenter" -t "$peer" -n "$ip" address add 10.203.0.2/30 dev peer0
"$nsenter" -t "$peer" -n "$ip" link set peer0 up
"$nsenter" -t "$peer" -n "$ip" -6 address add fd42:203::2/126 dev peer0 nodad
"$ip" address show > "$record/network-main"
"$nsenter" -t "$peer" -n "$ip" address show > "$record/network-peer"
if [[ $domain = epmd || $domain = stdlib || $domain = ssh ]]; then
    "$keygen" -q -t ed25519 -N '' -C otp-test-owned-host -f "$record/host-key"
    "$keygen" -q -t ed25519 -N '' -C otp-test-owned-client -f "$record/client-key"
    cp "$record/client-key.pub" "$record/authorized_keys"; chmod 600 "$record/authorized_keys"
    read -r kind public _ < "$record/host-key.pub"
    user=$(/usr/bin/id -nu "$OTP_CT_LINUX_UID")
fi
if [[ $domain = epmd ]]; then
    printf '[10.203.0.2]:2222 %s %s\n' "$kind" "$public" > "$record/known_hosts"
    printf 'Host otp-epmd-peer\n HostName 10.203.0.2\n Port 2222\n User %s\n IdentityFile "%s/client-key"\n IdentitiesOnly yes\n IdentityAgent none\n BatchMode yes\n StrictHostKeyChecking yes\n UserKnownHostsFile "%s/known_hosts"\n GlobalKnownHostsFile /dev/null\n ExitOnForwardFailure yes\n RequestTTY no\n ConnectTimeout 2\n ConnectionAttempts 1\n' "$user" "$record" "$record" > "$record/ssh-client/config"
    printf 'Port 2222\nListenAddress 10.203.0.2\nHostKey "%s/host-key"\nPidFile "%s/sshd.pid"\nAuthorizedKeysFile "%s/authorized_keys"\nUsePAM no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nAuthenticationMethods publickey\nStrictModes yes\nAllowUsers %s\nAllowTcpForwarding local\nPermitOpen %s:2243\nAllowAgentForwarding no\nX11Forwarding no\nPermitTTY no\nPrintMotd no\nLogLevel VERBOSE\n' "$record" "$record" "$record" "$user" "$hostname" > "$record/sshd_config"
    printf '127.0.0.1 localhost\n::1 localhost ip6-localhost ip6-loopback\n10.203.0.1 %s\n' "$hostname" > "$record/hosts-peer"
    "$nsenter" -t "$peer" -n "$bwrap" "${common[@]}" --dir /run/sshd --ro-bind "$record/hosts-peer" /etc/hosts "$sshd" -D -e -f "$record/sshd_config" > "$record/sshd.log" 2>&1 &
    daemon=$!
    ready=no
    printf -v route_command '%q route get 10.203.0.1' "$ip"
    for ((i=0;i<10;i++)); do
        if "$bwrap" "${common[@]}" --ro-bind "$record/hosts-main" /etc/hosts "$ssh" otp-epmd-peer "$route_command" > "$record/peer-route" 2> "$record/peer-check.log"; then ready=yes; break; fi
        /bin/sleep 0.1
    done
    [[ $ready = yes && $(< "$record/peer-route") = *'src 10.203.0.2'* ]]
    printf '{ssh_proxy_host,"otp-epmd-peer"}.\n' > "$record/epmd.config"
    export OTP_CT_LINUX_EPMD_CONFIG="$record/epmd.config"
    unset ERL_EPMD_ADDRESS
elif [[ $domain = stdlib || $domain = ssh ]]; then
    printf 'scope=private-network-namespace\nbefore=%s\n' "$(< /proc/sys/net/ipv4/ip_unprivileged_port_start)" > "$record/unprivileged-port-start"
    printf '0\n' > /proc/sys/net/ipv4/ip_unprivileged_port_start
    printf 'after=%s\n' "$(< /proc/sys/net/ipv4/ip_unprivileged_port_start)" >> "$record/unprivileged-port-start"
    printf 'localhost,127.0.0.1,127.0.1.1,::1,%s %s %s\n' "$hostname" "$kind" "$public" > "$record/known_hosts"
    cp "$record/client-key" "$record/ssh-client/id_ed25519"; cp "$record/client-key.pub" "$record/ssh-client/id_ed25519.pub"
    ln -s "$record/ssh-client" "$record/home/.ssh"
    printf 'Host localhost %s 127.0.0.1 ::1\n Port 22\n User %s\n IdentityFile "%s/client-key"\n IdentitiesOnly yes\n IdentityAgent none\n BatchMode yes\n StrictHostKeyChecking yes\n UserKnownHostsFile "%s/known_hosts"\n GlobalKnownHostsFile /dev/null\n ConnectTimeout 2\n ConnectionAttempts 1\n' "$hostname" "$user" "$record" "$record" > "$record/ssh-client/config"
    printf 'Port 22\nListenAddress 127.0.0.1\nListenAddress 127.0.1.1\nListenAddress ::1\nHostKey "%s/host-key"\nPidFile "%s/sshd.pid"\nAuthorizedKeysFile "%s/authorized_keys"\nUsePAM no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nAuthenticationMethods publickey\nStrictModes yes\nAllowUsers %s\nAllowTcpForwarding yes\nPermitTTY yes\nSubsystem sftp internal-sftp\nPrintMotd no\nLogLevel VERBOSE\n' "$record" "$record" "$record" "$user" > "$record/sshd_config"
    "$bwrap" "${common[@]}" --dir /run/sshd --ro-bind "$record/hosts-main" /etc/hosts "$sshd" -D -e -f "$record/sshd_config" > "$record/sshd.log" 2>&1 &
    daemon=$!
    ready=no
    for ((i=0;i<10;i++)); do
        if "$bwrap" "${common[@]}" --ro-bind "$record/hosts-main" /etc/hosts "$ssh" localhost true > "$record/localhost-check.log" 2>&1; then ready=yes; break; fi
        /bin/sleep 0.1
    done
    [[ $ready = yes ]]
fi
export PATH="$prefix/bin:${ssh%/*}:$PATH"
if [[ $gui = yes ]]; then
    mkdir -m 700 "$record/display-tools"
    ln -s "$xvfb" "$record/display-tools/Xvfb"; ln -s "$xauth" "$record/display-tools/xauth"
    : > "$record/Xauthority"
    "$bwrap" "${common[@]}" --ro-bind "$record/hosts-main" /etc/hosts --setenv PATH "$record/display-tools:$PATH" "$xvfb_run" -a -f "$record/Xauthority" -e "$record/xvfb.log" -s '-screen 0 1920x1080x24' "$BASH" "$self" --inner "${cli[@]}"
else
    "$bwrap" "${common[@]}" --ro-bind "$record/hosts-main" /etc/hosts "$BASH" "$self" --inner "${cli[@]}"
fi
