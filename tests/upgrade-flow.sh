#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
cleanup() { rm -rf -- "$test_dir"; }
trap cleanup EXIT

config_dir="$test_dir/config"
service_file="$test_dir/gost-socks.service"
lock_file="$test_dir/gost-socks.lock"
repository_dir="$test_dir/stable-repository"
snapshot_root="$test_dir/snapshots"
timeout_wrapper="$test_dir/timeout"
timeout_failure="$test_dir/timeout-failure"
safety_bin="$test_dir/socks-safety"
fake_bin="$test_dir/fakebin"
git_calls="$test_dir/git-calls"
real_git=$(command -v git)
mkdir -p "$config_dir" "$repository_dir/scripts" "$snapshot_root/previous-good/config" "$fake_bin"

cat >"$config_dir/node.env" <<'EOF'
NODE_NAME=fixture-node
PUBLIC_IP=192.0.2.10
SOCKS_PORT=31080
SOCKS_USERNAME=fixture_user
SOCKS_PASSWORD=fixture_password_123456
TOOL_VERSION=1.9.5
EOF
cat >"$service_file" <<'EOF'
[Service]
ExecStart=/usr/local/lib/gost-socks/gost -C /etc/gost-socks/gost.yaml
EOF

cat >"$timeout_wrapper" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${1:-} == --signal=TERM ]] && shift
shift
exec "$@"
EOF
cat >"$timeout_failure" <<'EOF'
#!/usr/bin/env bash
exit 124
EOF
cat >"$safety_bin" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
  verify) [[ -f ${2:-}/config/node.env ]] ;;
  restore) cp "${2:-}/config/node.env" "${SOCKS_CONFIG_DIR:?}/node.env" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$timeout_wrapper" "$timeout_failure" "$safety_bin"
cat >"$fake_bin/flock" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fake_bin/flock"
cat >"$fake_bin/git" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$git_calls"
exec "$real_git" "\$@"
EOF
chmod +x "$fake_bin/git"

printf '1.9.5\n' >"$repository_dir/VERSION"
printf '# fixture module\n' >"$repository_dir/scripts/socks-upgrade"
cat >"$repository_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} != --version ]] || { printf '1.9.5\n'; exit 0; }
exit 1
EOF
chmod +x "$repository_dir/install.sh"
git -C "$repository_dir" init -q
git -C "$repository_dir" add VERSION install.sh scripts/socks-upgrade
git -C "$repository_dir" -c user.name='Release Test' -c user.email='release-test@example.invalid' \
  commit -q -m 'fixture v1.9.5'
git -C "$repository_dir" tag v1.9.5

printf '1.10.0\n' >"$repository_dir/VERSION"
cat >"$repository_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${1:-} != --version ]] || { printf '1.10.0\n'; exit 0; }
config_dir=${SOCKS_CONFIG_DIR:?}
env_file="$config_dir/node.env"
port=""
preserve_node=false
bbr_policy=enabled
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) port=${2:-}; shift 2 ;;
    --preserve-node) preserve_node=true; shift ;;
    --no-bbr) bbr_policy=disabled; shift ;;
    --enable-bbr) bbr_policy=enabled; shift ;;
    *) printf 'fixture installer received unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done
[[ $preserve_node == true ]] || { printf 'fixture installer requires preserve mode\n' >&2; exit 1; }
existing_port=$(awk -F= '$1 == "SOCKS_PORT" {print $2}' "$env_file")
[[ $port == "$existing_port" ]] || { printf 'fixture port changed\n' >&2; exit 1; }
awk -F= -v bbr="$bbr_policy" '
  $1 == "TOOL_VERSION" {print "TOOL_VERSION=1.10.0"; version_found=1; next}
  $1 == "BBR_POLICY" {print "BBR_POLICY=" bbr; bbr_found=1; next}
  {print}
  END {
    if (!version_found) print "TOOL_VERSION=1.10.0"
    if (!bbr_found) print "BBR_POLICY=" bbr
  }' \
  "$env_file" >"$env_file.next"
mv "$env_file.next" "$env_file"
EOF
chmod +x "$repository_dir/install.sh"
git -C "$repository_dir" add VERSION install.sh
git -C "$repository_dir" -c user.name='Release Test' -c user.email='release-test@example.invalid' \
  commit -q -m 'fixture v1.10.0'
git -C "$repository_dir" tag v1.10.0

upgrade_environment=(
  "PATH=$fake_bin:$PATH"
  "SOCKS_CONFIG_DIR=$config_dir"
  "SOCKS_SERVICE_FILE=$service_file"
  "SOCKS_LOCK_FILE=$lock_file"
  "SOCKS_REPOSITORY_URL=$repository_dir"
  "SOCKS_TIMEOUT_BIN=$timeout_wrapper"
  "SOCKS_SAFETY_BIN=$safety_bin"
  "SOCKS_SNAPSHOT_ROOT=$snapshot_root"
)

before_identity=$(awk -F= '$1 != "TOOL_VERSION" && $1 != "BBR_POLICY" {print}' "$config_dir/node.env")
upgrade_output=$(env "${upgrade_environment[@]}" \
  "$project_dir/scripts/socks-upgrade" latest 2>&1)
after_identity=$(awk -F= '$1 != "TOOL_VERSION" && $1 != "BBR_POLICY" {print}' "$config_dir/node.env")

grep -Fq '版本切换只读检查通过' <<<"$upgrade_output"
grep -Fq '目标版本：v1.10.0' <<<"$upgrade_output"
grep -Fq '安全版本切换完成：1.9.5 → v1.10.0' <<<"$upgrade_output"
grep -Fq 'TOOL_VERSION=1.10.0' "$config_dir/node.env"
grep -Fq 'BBR_POLICY=enabled' "$config_dir/node.env"
if grep -Eq '输入 (UPGRADE|DOWNGRADE)' <<<"$upgrade_output"; then
  printf '正式版本切换不应要求第二次输入确认口令。\n' >&2
  exit 1
fi
[[ $before_identity == "$after_identity" ]] || {
  printf '完整版本切换流程改变了节点身份、IP、端口或凭据。\n' >&2
  exit 1
}
if grep -Fq 'fixture_password_123456' <<<"$upgrade_output"; then
  printf '完整版本切换流程输出了代理密码。\n' >&2
  exit 1
fi

cp "$config_dir/node.env" "$snapshot_root/previous-good/config/node.env"
sed -i.bak 's/TOOL_VERSION=1.10.0/TOOL_VERSION=1.9.5/' \
  "$snapshot_root/previous-good/config/node.env"
rm -f -- "$snapshot_root/previous-good/config/node.env.bak"

downgrade_check=$(env "${upgrade_environment[@]}" \
  "$project_dir/scripts/socks-upgrade" --check v1.9.5)
grep -Fq '恢复来源：previous-good' <<<"$downgrade_check"
if downgrade_denied=$(env "${upgrade_environment[@]}" \
  "$project_dir/scripts/socks-upgrade" v1.9.5 2>&1); then
  printf '没有 --allow-downgrade 时本应拒绝恢复旧版。\n' >&2
  exit 1
fi
grep -Fq '必须在同一命令中明确添加 --allow-downgrade' <<<"$downgrade_denied"

downgrade_output=$(env "${upgrade_environment[@]}" \
  "$project_dir/scripts/socks-upgrade" v1.9.5 --allow-downgrade)
grep -Fq '使用本机健康快照，无需下载' <<<"$downgrade_output"
grep -Fq 'TOOL_VERSION=1.9.5' "$config_dir/node.env"
after_downgrade_identity=$(awk -F= '$1 != "TOOL_VERSION" && $1 != "BBR_POLICY" {print}' "$config_dir/node.env")
[[ $before_identity == "$after_downgrade_identity" ]] || {
  printf '恢复旧版改变了节点身份、IP、端口或凭据。\n' >&2
  exit 1
}

: >"$git_calls"
exact_upgrade_output=$(env "${upgrade_environment[@]}" \
  "$project_dir/scripts/socks-upgrade" v1.10.0 --no-bbr 2>&1)
grep -Fq '安全版本切换完成：1.9.5 → v1.10.0' <<<"$exact_upgrade_output"
grep -Fq 'clone --quiet --branch v1.10.0 --depth 1' "$git_calls"
grep -Fq 'BBR_POLICY=disabled' "$config_dir/node.env"
if grep -Fq 'ls-remote' "$git_calls"; then
  printf '指定稳定标签的正式切换不应在 clone 前重复查询远端。\n' >&2
  exit 1
fi

timeout_output=""
if timeout_output=$(env "${upgrade_environment[@]}" SOCKS_TIMEOUT_BIN="$timeout_failure" \
  "$project_dir/scripts/socks-upgrade" --check latest 2>&1); then
  printf '最新版查询超时后版本切换器本应停止。\n' >&2
  exit 1
fi
grep -Fq '查询稳定标签超时或失败' <<<"$timeout_output"
grep -Fq 'TOOL_VERSION=1.10.0' "$config_dir/node.env"

printf '最新版、BBR开关、单次授权、健康快照降版、单次下载、凭据保留和超时停止测试通过。\n'
