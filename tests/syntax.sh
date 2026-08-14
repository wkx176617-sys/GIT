#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

files=(
  "$project_dir/deploy.sh"
  "$project_dir/xshell-install.sh"
  "$project_dir/install.sh"
  "$project_dir/preflight.sh"
  "$project_dir/overwrite.sh"
  "$project_dir/uninstall.sh"
  "$project_dir/scripts/socksctl"
  "$project_dir/scripts/socks-doctor"
  "$project_dir/scripts/socks-safety"
  "$project_dir/scripts/socks-refresh-ip"
  "$project_dir/scripts/socks-upgrade"
  "$project_dir/scripts/bbrctl"
  "$project_dir/scripts/release-check.sh"
  "$project_dir/tests/bbr-flow.sh"
  "$project_dir/tests/smart-install-flow.sh"
  "$project_dir/tests/upgrade-flow.sh"
)

for file in "${files[@]}"; do
  bash -n "$file"
done

command -v python3 >/dev/null 2>&1 || { printf '缺少文档导航检查所需的 Python 3。\n' >&2; exit 1; }
"$project_dir/scripts/docs-navigation" --check >/dev/null

"$project_dir/deploy.sh" --help >/dev/null
"$project_dir/xshell-install.sh" --help >/dev/null
"$project_dir/install.sh" --help >/dev/null
"$project_dir/preflight.sh" --help >/dev/null
"$project_dir/overwrite.sh" --help >/dev/null
"$project_dir/uninstall.sh" --help >/dev/null
"$project_dir/scripts/socksctl" --help >/dev/null
"$project_dir/scripts/socks-doctor" --help >/dev/null
"$project_dir/scripts/socks-safety" --help >/dev/null
"$project_dir/scripts/socks-refresh-ip" --help >/dev/null
"$project_dir/scripts/socks-upgrade" --help >/dev/null
"$project_dir/scripts/bbrctl" --help >/dev/null
if "$project_dir/install.sh" --help | grep -Fq -- '--preserve-node'; then
  printf '安装器帮助不应暴露升级器内部的保留模式，避免形成第二条升级路径。\n' >&2
  exit 1
fi

grep -q 'port=31080' "$project_dir/deploy.sh"
grep -q 'VERSION install.sh' "$project_dir/deploy.sh"
grep -q "remote_dir/scripts" "$project_dir/deploy.sh"
grep -q 'ControlMaster=auto' "$project_dir/deploy.sh"
grep -q 'ControlPersist=60' "$project_dir/deploy.sh"
grep -q -- '-O exit' "$project_dir/deploy.sh"
grep -q 'readonly GOST_VERSION="3.2.6"' "$project_dir/install.sh"
grep -q 'node_name=$public_ip' "$project_dir/install.sh"
grep -q 'PUBLIC_IP=$public_ip' "$project_dir/install.sh"
grep -q 'readonly TOOL_VERSION_CURRENT="1.12.2"' "$project_dir/install.sh"
grep -q 'for dependency_command in base64 .*qrencode' "$project_dir/install.sh"
grep -q 'apt-get install -y .*qrencode' "$project_dir/install.sh"
grep -q 'for required_command in base64 .*qrencode' "$project_dir/install.sh"
grep -q '仅缺失时执行一次 apt 更新' "$project_dir/install.sh"
grep -q 'control_source="$script_dir/scripts/socksctl"' "$project_dir/install.sh"
if grep -q 'control_source="$script_dir/socksctl"' "$project_dir/install.sh"; then
  printf '安装器仍可能优先使用根目录遗留的旧 socksctl。\n' >&2
  exit 1
fi
grep -q '工具版本：v$TOOL_VERSION_CURRENT' "$project_dir/install.sh"
grep -q '安装包发生混版' "$project_dir/xshell-install.sh"
grep -q 'refresh-ip' "$project_dir/scripts/socksctl"
grep -q 'upgrade latest|vX.Y.Z.*一条命令切换稳定版本' "$project_dir/scripts/socksctl"
grep -q 'exec "$UPGRADE" "$@"' "$project_dir/scripts/socksctl"
grep -q 'detect_public_ip_consensus' "$project_dir/scripts/socks-refresh-ip"
grep -q 'winner_count >= 2' "$project_dir/scripts/socks-refresh-ip"
grep -q '输入 REFRESH-IP 确认' "$project_dir/scripts/socks-refresh-ip"
grep -q 'trap rollback ERR' "$project_dir/scripts/socks-refresh-ip"
grep -q -- '--check' "$project_dir/scripts/socks-refresh-ip"
grep -q 'proxy_public_ip' "$project_dir/scripts/socks-refresh-ip"
grep -q '没有发现本项目节点' "$project_dir/scripts/socks-upgrade"
grep -q '推荐用法' "$project_dir/scripts/socks-upgrade"
grep -q 'socks-upgrade latest' "$project_dir/scripts/socks-upgrade"
grep -q '不再重复询问' "$project_dir/scripts/socks-upgrade"
grep -q -- '--allow-downgrade' "$project_dir/scripts/socks-upgrade"
grep -q 'find_compatible_snapshot' "$project_dir/scripts/socks-upgrade"
grep -q '使用本机健康快照，无需下载' "$project_dir/scripts/socks-upgrade"
if rg -n '输入 (UPGRADE|DOWNGRADE)' "$project_dir/scripts/socks-upgrade" "$project_dir/install.sh"; then
  printf '版本切换不应重复要求第二个确认口令。\n' >&2
  exit 1
fi
grep -q 'git ls-remote --tags' "$project_dir/scripts/socks-upgrade"
grep -q 'TAG_CHECK_TIMEOUT_SECONDS' "$project_dir/scripts/socks-upgrade"
grep -q 'CLONE_TIMEOUT_SECONDS' "$project_dir/scripts/socks-upgrade"
clone_line=$(grep -n 'advice.detachedHead=false clone' "$project_dir/scripts/socks-upgrade" | cut -d: -f1)
switch_lock_line=$(grep -n 'flock -n 9' "$project_dir/scripts/socks-upgrade" | cut -d: -f1)
[[ $clone_line =~ ^[0-9]+$ && $switch_lock_line =~ ^[0-9]+$ && $clone_line -lt $switch_lock_line ]] || {
  printf '稳定包下载应在获取维护锁之前完成，避免慢网络长期阻塞其他管理任务。\n' >&2
  exit 1
}
grep -q 'preserve_node == true && -x $BINARY_PATH' "$project_dir/install.sh"
grep -q 'existing_gost_identity=.*-V' "$project_dir/install.sh"
grep -q 'existing_gost_identity == "gost v$GOST_VERSION"' "$project_dir/install.sh"
grep -q 'downloaded_binary=$BINARY_PATH' "$project_dir/install.sh"
grep -q '\[\[ -z $downloaded_binary \]\]' "$project_dir/install.sh"
grep -q '本次工具升级复用现有核心，不重复下载' "$project_dir/install.sh"
grep -q -- '--connect-timeout 10 --max-time 300' "$project_dir/install.sh"
grep -q 'SOCKS_LOCK_HELD=1 bash' "$project_dir/scripts/socks-upgrade"
grep -q -- '--preserve-node' "$project_dir/scripts/socks-upgrade"
grep -q 'INSTALL_PRESERVATION_FAILED' "$project_dir/install.sh"
grep -q '无法创建升级前事务快照' "$project_dir/install.sh"
grep -q 'socks-upgrade' "$project_dir/uninstall.sh"
grep -q '安全跳过' "$project_dir/install.sh"
grep -q 'gost-socks-main.lock' "$project_dir/install.sh"
grep -q 'INSTALL_UNKNOWN' "$project_dir/install.sh"
grep -q 'INSTALL_SERVICE_NOT_READY' "$project_dir/install.sh"
grep -q 'startup_attempt<=15' "$project_dir/install.sh"
grep -q 'tools-present' "$project_dir/scripts/socks-safety"
grep -q 'wait_for_service_ready' "$project_dir/scripts/socks-safety"
if grep -q 'chmod -R go-rwx' "$project_dir/scripts/socks-safety"; then
  printf '快照模块不得递归移除 GOST 服务用户所需的执行权限。\n' >&2
  exit 1
fi
grep -q 'HEAL_BLOCKED_UNCERTAIN' "$project_dir/scripts/socksctl"
grep -q 'CONFIG_MISSING|CONFIG_PERMISSION|CONFIG_MISMATCH' "$project_dir/scripts/socksctl"
grep -q 'PORT_CONFLICT' "$project_dir/scripts/socks-doctor"
grep -q 'CONFIG_INVALID' "$project_dir/scripts/socks-doctor"
if rg -n 'source "?\$ENV_FILE' "$project_dir/install.sh" "$project_dir/scripts/socksctl" "$project_dir/scripts/socks-doctor"; then
  printf '主程序不应把凭据文件作为 Shell 代码载入。\n' >&2
  exit 1
fi
grep -q '脱敏报告已生成' "$project_dir/scripts/socksctl"
grep -q -- '--no-record' "$project_dir/scripts/socks-doctor"
grep -q 'sleep 2' "$project_dir/scripts/socks-doctor"
grep -q 'StartLimitIntervalSec=60' "$project_dir/install.sh"
grep -q 'StartLimitBurst=5' "$project_dir/install.sh"
grep -q 'RestartSec=5s' "$project_dir/install.sh"
grep -q 'RECOVERY_LOOP' "$project_dir/scripts/socksctl"
grep -q 'SOCKS5 中文新手菜单' "$project_dir/scripts/socksctl"
grep -q 'allow-downgrade' "$project_dir/install.sh"
grep -q 'docs-nav:start' "$project_dir/docs/tutorial.md"
grep -q '返回上一级' "$project_dir/docs/tutorial.md"
grep -q '快速搜索' "$project_dir/docs/tutorial.md"
grep -q 'fetch(MANIFEST_URL' "$project_dir/docs/navigator/app.js"
grep -q '不连接 VPS' "$project_dir/docs/navigator/index.html"
if grep -q 'apt-get' "$project_dir/xshell-install.sh"; then
  printf 'Xshell入口不应在安装器之前重复运行 apt 更新或依赖安装。\n' >&2
  exit 1
fi
if rg -n 'RESTART_RECOVERED|RESTART_RECOVERY_FAILED' "$project_dir/scripts/socksctl"; then
  printf '重启失败仍在自动恢复，不符合克制维修规则。\n' >&2
  exit 1
fi
grep -q '20.04|22.04|24.04' "$project_dir/preflight.sh"
grep -q '/root/gost-socks-backups' "$project_dir/overwrite.sh"
grep -q 'systemctl disable --now sing-box' "$project_dir/overwrite.sh"
grep -q 'trap rollback ERR' "$project_dir/overwrite.sh"
grep -q 'exit 10' "$project_dir/preflight.sh"
grep -q 'preflight_status == 10' "$project_dir/overwrite.sh"
grep -q 'exec bash "$script_dir/overwrite.sh"' "$project_dir/xshell-install.sh"
grep -q '旧代理账号密码已作废' "$project_dir/overwrite.sh"
grep -q 'new_username != "$username"' "$project_dir/overwrite.sh"
grep -q 'new_password != "$password"' "$project_dir/overwrite.sh"
grep -q '! systemctl is-active --quiet sing-box' "$project_dir/overwrite.sh"
grep -q '! systemctl is-enabled --quiet sing-box' "$project_dir/overwrite.sh"
grep -q '\[\[ ! -e /etc/sing-box \]\]' "$project_dir/overwrite.sh"
if rg -n 'MIGRATE_SOCKS_(USERNAME|PASSWORD)' "$project_dir/overwrite.sh"; then
  printf '旧协议迁移不得继续复用旧代理凭据。\n' >&2
  exit 1
fi
grep -q 'net.ipv4.tcp_congestion_control = bbr' "$project_dir/scripts/bbrctl"
grep -q 'net.core.default_qdisc = fq' "$project_dir/scripts/bbrctl"
grep -q 'trap rollback_enable ERR' "$project_dir/scripts/bbrctl"
grep -q '重复 enable 已安全跳过' "$project_dir/scripts/bbrctl"
grep -q 'find_conflicts' "$project_dir/scripts/bbrctl"
grep -q 'preflight)' "$project_dir/scripts/bbrctl"
grep -q '输入 RESTORE-BBR 确认' "$project_dir/scripts/bbrctl"
grep -q 'BBR_POLICY=$bbr_policy' "$project_dir/install.sh"
grep -q 'bbr_policy=enabled' "$project_dir/install.sh"
grep -q -- '--no-bbr' "$project_dir/install.sh"
grep -q '"$BBR_PATH" enable' "$project_dir/install.sh"
grep -q 'bbr <命令>' "$project_dir/scripts/socksctl"
grep -q 'BBR_INACTIVE' "$project_dir/scripts/socks-doctor"
grep -q '/usr/local/sbin/bbrctl restore --yes' "$project_dir/uninstall.sh"
if find "$project_dir/addons" -mindepth 2 -maxdepth 2 -name plugin.conf -type f | grep -q .; then
  printf '插件中心应暂时为空。\n' >&2
  exit 1
fi
if rg -n 'crontab|/etc/cron|systemctl[[:space:]]+(enable|start).*\.timer|docker[[:space:]]+run|podman[[:space:]]+run' \
  "$project_dir/deploy.sh" "$project_dir/install.sh" "$project_dir/xshell-install.sh" \
  "$project_dir/preflight.sh" "$project_dir/overwrite.sh" "$project_dir/scripts/socksctl" \
  "$project_dir/scripts/socks-doctor" "$project_dir/scripts/socks-safety" \
  "$project_dir/scripts/socks-refresh-ip" "$project_dir/scripts/socks-upgrade"; then
  printf '核心程序引入了定时任务、容器或后台调度，违反轻量架构边界。\n' >&2
  exit 1
fi

upgrade_test_dir=$(mktemp -d)
upgrade_config_dir="$upgrade_test_dir/config"
upgrade_service_file="$upgrade_test_dir/gost-socks.service"
upgrade_timeout_wrapper="$upgrade_test_dir/timeout"
mkdir -p "$upgrade_config_dir"
cat >"$upgrade_timeout_wrapper" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == --signal=TERM ]] && shift
shift
exec "$@"
EOF
chmod +x "$upgrade_timeout_wrapper"

write_upgrade_fixture() {
  local fixture_version=$1
  cat >"$upgrade_config_dir/node.env" <<EOF
NODE_NAME=fixture-node
PUBLIC_IP=192.0.2.10
SOCKS_PORT=31080
SOCKS_USERNAME=fixture_user
SOCKS_PASSWORD=fixture_password_123456
TOOL_VERSION=$fixture_version
EOF
  cat >"$upgrade_service_file" <<'EOF'
[Service]
ExecStart=/usr/local/lib/gost-socks/gost -C /etc/gost-socks/gost.yaml
EOF
}

upgrade_env=(
  "SOCKS_CONFIG_DIR=$upgrade_config_dir"
  "SOCKS_SERVICE_FILE=$upgrade_service_file"
  "SOCKS_REPOSITORY_URL=$project_dir"
  "SOCKS_LOCK_FILE=$upgrade_test_dir/upgrade.lock"
  "SOCKS_TIMEOUT_BIN=$upgrade_timeout_wrapper"
)

expect_upgrade_failure() {
  local expected_text=$1
  shift
  local failure_output
  if failure_output=$(env "${upgrade_env[@]}" "$project_dir/scripts/socks-upgrade" "$@" 2>&1); then
    printf '升级器本应拒绝该测试场景：%s\n' "$*" >&2
    exit 1
  fi
  grep -Fq "$expected_text" <<<"$failure_output" || {
    printf '升级器拒绝原因不符合预期：%s\n%s\n' "$expected_text" "$failure_output" >&2
    exit 1
  }
}

write_upgrade_fixture 1.8.0
current_output=$(env "${upgrade_env[@]}" "$project_dir/scripts/socks-upgrade" --current)
grep -Fq '当前工具版本：1.8.0' <<<"$current_output"
before_check=$(cksum "$upgrade_config_dir/node.env" "$upgrade_service_file")
check_output=$(env "${upgrade_env[@]}" "$project_dir/scripts/socks-upgrade" --check v1.8.1)
after_check=$(cksum "$upgrade_config_dir/node.env" "$upgrade_service_file")
[[ $before_check == "$after_check" ]]
grep -Fq '只读检查结束，没有修改服务器' <<<"$check_output"
if grep -Fq 'fixture_password_123456' <<<"$check_output"; then
  printf '升级只读检查泄露了代理密码。\n' >&2
  exit 1
fi

write_upgrade_fixture 1.8.1
expect_upgrade_failure '无需重复升级' --check v1.8.1
expect_upgrade_failure '缺少安全快照模块' --check v1.8.0
expect_upgrade_failure '目标必须是 latest 或完整稳定标签' --check main

write_upgrade_fixture 1.8.1
latest_check_output=$(env "${upgrade_env[@]}" "$project_dir/scripts/socks-upgrade" --check latest)
grep -Fq '目标版本：v' <<<"$latest_check_output"
grep -Fq 'GitHub 已找到' <<<"$latest_check_output"

write_upgrade_fixture 1.8.0
expect_upgrade_failure 'GitHub 上没有找到稳定标签' --check v9.9.9
printf '%s\n' '[Service]' 'ExecStart=/usr/bin/unknown-proxy' >"$upgrade_service_file"
expect_upgrade_failure '服务文件不属于当前项目' --check v1.8.1
mkdir -p "$upgrade_test_dir/empty-config"
missing_env=(
  "SOCKS_CONFIG_DIR=$upgrade_test_dir/empty-config"
  "SOCKS_SERVICE_FILE=$upgrade_service_file"
  "SOCKS_REPOSITORY_URL=$project_dir"
  "SOCKS_LOCK_FILE=$upgrade_test_dir/missing.lock"
)
if missing_output=$(env "${missing_env[@]}" "$project_dir/scripts/socks-upgrade" --current 2>&1); then
  printf '升级器不应把空目录识别为本项目节点。\n' >&2
  exit 1
fi
grep -Fq '没有发现本项目节点' <<<"$missing_output"
rm -rf -- "$upgrade_test_dir"

incident_test_dir=$(mktemp -d)
first_incident=$(SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" \
  incident TEST_UNKNOWN record saved deterministic-test)
second_incident=$(SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" \
  incident TEST_UNKNOWN record saved deterministic-test)
first_note=$(SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" \
  incident USER_OBSERVATION observe recorded first-note)
second_note=$(SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" \
  incident USER_OBSERVATION observe recorded different-note)
SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" incidents "$first_incident" \
  | grep -Fq 'yes'
SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" incidents "$second_incident" \
  | grep -Fq 'no'
SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" incidents "$first_note" \
  | grep -Fq 'yes'
SOCKS_SAFETY_ROOT="$incident_test_dir" "$project_dir/scripts/socks-safety" incidents "$second_note" \
  | grep -Fq 'yes'
rm -rf -- "$incident_test_dir"

redaction_password='secret.with.dots'
redaction_username='user.with.dots'
redaction_input="user=$redaction_username password=$redaction_password"
escaped_password=${redaction_password//./\\.}
escaped_username=${redaction_username//./\\.}
redaction_output=$(printf '%s\n' "$redaction_input" \
  | sed -e "s/$escaped_password/[REDACTED_PASSWORD]/g" \
        -e "s/$escaped_username/[REDACTED_USER]/g")
[[ $redaction_output == 'user=[REDACTED_USER] password=[REDACTED_PASSWORD]' ]]

safety_test_dir=$(mktemp -d)
mkdir -p "$safety_test_dir/fakebin" "$safety_test_dir/etc/gost-socks" \
  "$safety_test_dir/usr/local/lib/gost-socks" "$safety_test_dir/usr/local/sbin" \
  "$safety_test_dir/systemd"
cat >"$safety_test_dir/fakebin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  is-enabled) printf 'enabled\n' ;;
  is-active) printf 'active\n' ;;
esac
exit 0
EOF
cat >"$safety_test_dir/fakebin/ss" <<'EOF'
#!/usr/bin/env bash
counter_file=${SOCKS_TEST_SS_COUNTER:?}
counter=$(cat "$counter_file" 2>/dev/null || printf '0')
counter=$((counter + 1))
printf '%s\n' "$counter" >"$counter_file"
(( counter >= 2 )) || exit 0
printf 'LISTEN 0 4096 0.0.0.0:31080 0.0.0.0:*\n'
EOF
chmod +x "$safety_test_dir/fakebin/systemctl" "$safety_test_dir/fakebin/ss"
cat >"$safety_test_dir/etc/gost-socks/node.env" <<'EOF'
NODE_NAME=old
PUBLIC_IP=203.0.113.10
SOCKS_PORT=31080
SOCKS_USERNAME=node_example
SOCKS_PASSWORD=0123456789abcdef0123456789abcdef
TOOL_VERSION=1.6.1
EOF
cat >"$safety_test_dir/etc/gost-socks/gost.yaml" <<'EOF'
services:
  - addr: ":31080"
    handler:
      auth:
        username: "node_example"
        password: "0123456789abcdef0123456789abcdef"
EOF
printf 'binary-old\n' >"$safety_test_dir/usr/local/lib/gost-socks/gost"
chmod 0755 "$safety_test_dir/usr/local/lib/gost-socks" \
  "$safety_test_dir/usr/local/lib/gost-socks/gost"
for safety_tool in socksctl socks-uninstall socks-doctor socks-safety socks-refresh-ip socks-upgrade; do
  printf 'old-%s\n' "$safety_tool" >"$safety_test_dir/usr/local/sbin/$safety_tool"
  chmod 0755 "$safety_test_dir/usr/local/sbin/$safety_tool"
done
printf 'ExecStart=/fake/gost\n' >"$safety_test_dir/systemd/gost-socks.service"
safety_command=(env PATH="$safety_test_dir/fakebin:$PATH" \
  SOCKS_TEST_SS_COUNTER="$safety_test_dir/ss-counter" \
  SOCKS_SAFETY_ROOT="$safety_test_dir/state" \
  SOCKS_CONFIG_DIR="$safety_test_dir/etc/gost-socks" \
  SOCKS_BINARY_DIR="$safety_test_dir/usr/local/lib/gost-socks" \
  SOCKS_SERVICE_FILE="$safety_test_dir/systemd/gost-socks.service" \
  SOCKS_TOOLS_DIR="$safety_test_dir/usr/local/sbin" \
  "$project_dir/scripts/socks-safety")
transaction_snapshot=$("${safety_command[@]}" snapshot)
"${safety_command[@]}" verify "$transaction_snapshot" | grep -Fq '快照校验通过'
find "$transaction_snapshot/binary" -maxdepth 0 -perm -001 | grep -Fq '/binary'
find "$transaction_snapshot/binary/gost" -maxdepth 0 -perm -001 | grep -Fq '/gost'
grep -Fxq 'socksctl' "$transaction_snapshot/tools-present"
grep -Fq 'old-socksctl' "$transaction_snapshot/tools/socksctl"
sed -i.bak 's/NODE_NAME=old/NODE_NAME=new/' "$safety_test_dir/etc/gost-socks/node.env"
rm -f -- "$safety_test_dir/etc/gost-socks/node.env.bak"
printf 'new-socksctl\n' >"$safety_test_dir/usr/local/sbin/socksctl"
chmod 0755 "$safety_test_dir/usr/local/sbin/socksctl"
"${safety_command[@]}" promote "$transaction_snapshot" >/dev/null
grep -Fq 'NODE_NAME=old' "$safety_test_dir/state/snapshots/previous-good/config/node.env"
grep -Fq 'NODE_NAME=new' "$safety_test_dir/state/snapshots/last-good/config/node.env"
# 模拟 v1.9.1 把快照目录和二进制错误收紧为 0700；内容校验仍有效，恢复必须兼容纠正权限。
chmod 0700 "$safety_test_dir/state/snapshots/previous-good/binary" \
  "$safety_test_dir/state/snapshots/previous-good/binary/gost"
printf 'broken\n' >"$safety_test_dir/etc/gost-socks/node.env"
"${safety_command[@]}" restore "$safety_test_dir/state/snapshots/previous-good" >/dev/null
[[ $(cat "$safety_test_dir/ss-counter") == 2 ]]
grep -Fq 'NODE_NAME=old' "$safety_test_dir/etc/gost-socks/node.env"
grep -Fq 'old-socksctl' "$safety_test_dir/usr/local/sbin/socksctl"
find "$safety_test_dir/usr/local/lib/gost-socks" -maxdepth 0 -perm -001 | grep -Fq 'gost-socks'
find "$safety_test_dir/usr/local/lib/gost-socks/gost" -maxdepth 0 -perm -001 | grep -Fq '/gost'
find "$safety_test_dir/etc/gost-socks" -maxdepth 0 -perm -010 | grep -Fq 'gost-socks'
find "$safety_test_dir/usr/local/sbin/socksctl" -maxdepth 0 -perm -001 | grep -Fq 'socksctl'
"${safety_command[@]}" snapshots | grep -Fq 'previous-good'
"${safety_command[@]}" recovery-guard CONFIG_MISSING
"${safety_command[@]}" recovery-mark CONFIG_MISSING
if "${safety_command[@]}" recovery-guard CONFIG_MISSING 2>/dev/null; then
  printf '自动恢复熔断器没有阻止短时间内的相同故障。\n' >&2
  exit 1
fi
printf 'tampered\n' >>"$safety_test_dir/state/snapshots/last-good/config/node.env"
if "${safety_command[@]}" verify "$safety_test_dir/state/snapshots/last-good" >/dev/null 2>&1; then
  printf '快照校验没有发现内容被修改。\n' >&2
  exit 1
fi
rm -rf -- "$safety_test_dir"

refresh_test_dir=$(mktemp -d)
mkdir -p "$refresh_test_dir/fakebin" "$refresh_test_dir/config"
cat >"$refresh_test_dir/fakebin/curl" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
  one|two) printf '198.51.100.22\n' ;;
  three) printf '203.0.113.99\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$refresh_test_dir/fakebin/curl"
cat >"$refresh_test_dir/config/node.env" <<'EOF'
NODE_NAME=203.0.113.10
PUBLIC_IP=203.0.113.10
SOCKS_PORT=31080
SOCKS_USERNAME=node_example
SOCKS_PASSWORD=0123456789abcdef0123456789abcdef
TOOL_VERSION=1.8.0
EOF
cat >"$refresh_test_dir/config/gost.yaml" <<'EOF'
services:
  - name: "203.0.113.10"
    addr: ":31080"
EOF
printf 'Description=GOST SOCKS5 Proxy (203.0.113.10)\n' >"$refresh_test_dir/gost-socks.service"
refresh_check_output=$(env PATH="$refresh_test_dir/fakebin:$PATH" \
  SOCKS_CONFIG_DIR="$refresh_test_dir/config" \
  SOCKS_SERVICE_FILE="$refresh_test_dir/gost-socks.service" \
  SOCKS_IP_ENDPOINTS='one two three' \
  "$project_dir/scripts/socks-refresh-ip" --check)
grep -Fq '当前检测到的公网IP：198.51.100.22' <<<"$refresh_check_output"
grep -Fq '检测到变化' <<<"$refresh_check_output"
grep -Fq 'PUBLIC_IP=203.0.113.10' "$refresh_test_dir/config/node.env"
rm -rf -- "$refresh_test_dir"

if command -v jq >/dev/null 2>&1; then
  legacy_config="$project_dir/tests/sing-box.legacy.json"
  match_count=$(jq --argjson port 31080 '[.inbounds[]? | select(.type == "socks" and .listen_port == $port)] | length' "$legacy_config")
  legacy_username=$(jq -r --argjson port 31080 '.inbounds[]? | select(.type == "socks" and .listen_port == $port) | .users[0].username // empty' "$legacy_config")
  legacy_password=$(jq -r --argjson port 31080 '.inbounds[]? | select(.type == "socks" and .listen_port == $port) | .users[0].password // empty' "$legacy_config")
  [[ $match_count == 1 && $legacy_username == node_example ]]
  [[ $legacy_password == 0123456789abcdef0123456789abcdef ]]
fi

test_config_dir=$(mktemp -d)
cleanup() { rm -rf -- "$test_config_dir"; }
trap cleanup EXIT
cat >"$test_config_dir/node.env" <<'EOF'
NODE_NAME=203.0.113.10
PUBLIC_IP=203.0.113.10
SOCKS_PORT=31080
SOCKS_USERNAME=node_example
SOCKS_PASSWORD=0123456789abcdef0123456789abcdef
EOF
chmod 0600 "$test_config_dir/node.env"
export_output=$(SOCKSCTL_CONFIG_DIR="$test_config_dir" "$project_dir/scripts/socksctl" export all 2>/dev/null)
grep -Fq 'socks://bm9kZV9leGFtcGxlOjAxMjM0NTY3ODlhYmNkZWYwMTIzNDU2Nzg5YWJjZGVm@203.0.113.10:31080#203.0.113.10' <<<"$export_output"
grep -Fq 'socks5://node_example:0123456789abcdef0123456789abcdef@203.0.113.10:31080#203.0.113.10' <<<"$export_output"
grep -Fq '203.0.113.10=socks5,203.0.113.10,31080,node_example,0123456789abcdef0123456789abcdef' <<<"$export_output"
mkdir -p "$test_config_dir/fakebin"
cat >"$test_config_dir/fakebin/qrencode" <<'EOF'
#!/usr/bin/env bash
printf 'QR参数：%s\n' "$*"
EOF
chmod +x "$test_config_dir/fakebin/qrencode"
qr_output=$(PATH="$test_config_dir/fakebin:$PATH" SOCKSCTL_CONFIG_DIR="$test_config_dir" \
  "$project_dir/scripts/socksctl" qr shadowrocket)
grep -Fq '请使用自己的设备扫描' <<<"$qr_output"
grep -Fq 'QR参数：-t ANSIUTF8 socks5://node_example:0123456789abcdef0123456789abcdef@203.0.113.10:31080#203.0.113.10' \
  <<<"$qr_output"
unexpected_ips=$(rg -o --no-filename '([0-9]{1,3}\.){3}[0-9]{1,3}' "$project_dir" \
  -g '!.git/**' | sort -u \
  | grep -Ev '^(0\.0\.0\.0|127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.0\.2\.[0-9]{1,3}|198\.51\.100\.[0-9]{1,3}|203\.0\.113\.[0-9]{1,3})$' \
  || true)
if [[ -n $unexpected_ips ]]; then
  printf '检测到不属于文档示例网段的 IPv4：\n%s\n' "$unexpected_ips" >&2
  exit 1
fi
if grep -R -nE 'SOCKS_PASSWORD=[^$]' "$project_dir" --exclude-dir=.git \
  --exclude='syntax.sh' --exclude='upgrade-flow.sh'; then
  printf '检测到仓库文件写入明文节点密码。\n' >&2
  exit 1
fi
if grep -R -nE 'BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|socks5?://[A-Za-z0-9._-]{4,32}:[A-Za-z0-9._-]{16,64}@' \
  "$project_dir" --exclude-dir=.git --exclude='syntax.sh' --exclude='upgrade-flow.sh'; then
  printf '检测到疑似私钥、Token 或带真实凭据的代理链接。\n' >&2
  exit 1
fi
sensitive_key_files=$(find "$project_dir" -path "$project_dir/.git" -prune -o -type f \
  \( -name '*.pem' -o -name '*.key' -o -name 'id_rsa' -o -name 'id_ed25519' \) -print)
if [[ -n $sensitive_key_files ]]; then
  printf '检测到不应进入仓库的私钥文件名：\n%s\n' "$sensitive_key_files" >&2
  exit 1
fi

printf 'Shell 语法与帮助信息测试通过。\n'
