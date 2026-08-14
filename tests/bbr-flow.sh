#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
cleanup() { rm -rf -- "$test_dir"; }
trap cleanup EXIT

state_dir="$test_dir/state"
sysctl_root="$test_dir/etc"
fake_bin="$test_dir/fakebin"
values_file="$test_dir/sysctl-values"
mkdir -p "$state_dir" "$sysctl_root/sysctl.d" "$fake_bin"

cat >"$test_dir/os-release" <<'EOF'
ID=ubuntu
VERSION_ID=22.04
EOF
cat >"$values_file" <<'EOF'
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=cubic
net.ipv4.tcp_available_congestion_control=reno cubic bbr
EOF

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == -m ]] && printf 'x86_64\n' || printf 'Linux\n'
EOF
cat >"$fake_bin/modinfo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$fake_bin/modprobe" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$fake_bin/flock" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$fake_bin/sysctl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
values_file=${BBR_TEST_VALUES:?}
read_value() {
  awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$values_file"
}
write_value() {
  local key=$1 value=$2 next_file="$values_file.next"
  awk -F= -v key="$key" -v value="$value" '
    $1 == key {print key "=" value; found=1; next}
    {print}
    END {if (!found) print key "=" value}
  ' "$values_file" >"$next_file"
  mv "$next_file" "$values_file"
}
case "${1:-}" in
  -n) read_value "$2" ;;
  -w)
    assignment=$2
    write_value "${assignment%%=*}" "${assignment#*=}"
    ;;
  -p)
    while IFS='=' read -r key value; do
      key=$(printf '%s' "$key" | tr -d '[:space:]')
      value=$(printf '%s' "$value" | tr -d '[:space:]')
      [[ -n $key && $key != \#* ]] && write_value "$key" "$value"
    done <"$2"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$fake_bin"/*

bbr_env=(
  "PATH=$fake_bin:$PATH"
  "BBR_ALLOW_NON_ROOT_TESTS=1"
  "BBR_STATE_DIR=$state_dir"
  "BBR_SYSCTL_ROOT=$sysctl_root"
  "BBR_LOCK_FILE=$test_dir/bbr.lock"
  "BBR_OS_RELEASE_FILE=$test_dir/os-release"
  "BBR_TEST_VALUES=$values_file"
)

env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" preflight >/dev/null
enable_output=$(env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" enable)
grep -Fq 'BBR + FQ 已启用并持久化' <<<"$enable_output"
grep -Fq 'ORIGINAL_QDISC=fq_codel' "$state_dir/original.conf"
grep -Fq 'ORIGINAL_CC=cubic' "$state_dir/original.conf"
grep -Fq 'net.core.default_qdisc=fq' "$values_file"
grep -Fq 'net.ipv4.tcp_congestion_control=bbr' "$values_file"

repeat_output=$(env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" enable)
grep -Fq '重复 enable 已安全跳过' <<<"$repeat_output"
env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" health >/dev/null

env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" restore --yes >/dev/null
[[ ! -f $sysctl_root/sysctl.d/99-gost-socks-bbr.conf ]]
grep -Fq 'net.core.default_qdisc=fq_codel' "$values_file"
grep -Fq 'net.ipv4.tcp_congestion_control=cubic' "$values_file"

cat >"$sysctl_root/sysctl.d/50-external.conf" <<'EOF'
net.ipv4.tcp_congestion_control = cubic
EOF
if env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" preflight >/dev/null 2>&1; then
  printf '冲突 sysctl 存在时安装前质检本应停止。\n' >&2
  exit 1
fi
if env "${bbr_env[@]}" "$project_dir/scripts/bbrctl" enable >/dev/null 2>&1; then
  printf '冲突 sysctl 存在时启用本应停止。\n' >&2
  exit 1
fi
grep -Fq 'net.ipv4.tcp_congestion_control=cubic' "$values_file"

printf 'BBR支持、默认启用、幂等、冲突停止和恢复测试通过。\n'
