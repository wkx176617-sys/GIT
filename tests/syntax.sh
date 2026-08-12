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
  "$project_dir/scripts/release-check.sh"
  "$project_dir/addons/bbr/bbrctl"
  "$project_dir/addons/bbr/install.sh"
  "$project_dir/addons/bbr/uninstall.sh"
)

for file in "${files[@]}"; do
  bash -n "$file"
done

"$project_dir/deploy.sh" --help >/dev/null
"$project_dir/xshell-install.sh" --help >/dev/null
"$project_dir/install.sh" --help >/dev/null
"$project_dir/preflight.sh" --help >/dev/null
"$project_dir/overwrite.sh" --help >/dev/null
"$project_dir/uninstall.sh" --help >/dev/null
"$project_dir/scripts/socksctl" --help >/dev/null
"$project_dir/scripts/socks-doctor" --help >/dev/null
"$project_dir/scripts/socks-safety" --help >/dev/null
"$project_dir/addons/bbr/bbrctl" --help >/dev/null
"$project_dir/addons/bbr/install.sh" --help >/dev/null
"$project_dir/addons/bbr/uninstall.sh" --help >/dev/null

grep -q 'port=31080' "$project_dir/deploy.sh"
grep -q 'readonly GOST_VERSION="3.2.6"' "$project_dir/install.sh"
grep -q 'node_name=$public_ip' "$project_dir/install.sh"
grep -q 'PUBLIC_IP=$public_ip' "$project_dir/install.sh"
grep -q 'readonly TOOL_VERSION_CURRENT="1.7.2"' "$project_dir/install.sh"
grep -q '安全跳过' "$project_dir/install.sh"
grep -q 'gost-socks-main.lock' "$project_dir/install.sh"
grep -q 'INSTALL_UNKNOWN' "$project_dir/install.sh"
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
if rg -n 'RESTART_RECOVERED|RESTART_RECOVERY_FAILED' "$project_dir/scripts/socksctl"; then
  printf '重启失败仍在自动恢复，不符合克制维修规则。\n' >&2
  exit 1
fi
grep -q '20.04|22.04|24.04' "$project_dir/preflight.sh"
grep -q '/root/gost-socks-backups' "$project_dir/overwrite.sh"
grep -q 'systemctl disable --now sing-box' "$project_dir/overwrite.sh"
grep -q 'trap rollback ERR' "$project_dir/overwrite.sh"
grep -q '^PLUGIN_VERSION=1.1.0$' "$project_dir/addons/bbr/plugin.conf"
grep -q '^MAIN_MIN_VERSION=1.4.0$' "$project_dir/addons/bbr/plugin.conf"
grep -q '^MAIN_MAX_MAJOR=1$' "$project_dir/addons/bbr/plugin.conf"
grep -q 'net.ipv4.tcp_congestion_control = bbr' "$project_dir/addons/bbr/bbrctl"
grep -q 'net.core.default_qdisc = fq' "$project_dir/addons/bbr/bbrctl"
grep -q 'trap rollback_enable ERR' "$project_dir/addons/bbr/bbrctl"
grep -q '重复 enable 已安全跳过' "$project_dir/addons/bbr/bbrctl"
grep -q 'find_conflicts' "$project_dir/addons/bbr/bbrctl"
if rg -n 'bbrctl|addons/bbr|tcp_congestion_control' \
  "$project_dir/deploy.sh" "$project_dir/install.sh" "$project_dir/xshell-install.sh" \
  "$project_dir/preflight.sh" "$project_dir/overwrite.sh" "$project_dir/scripts/socksctl"; then
  printf 'BBR 插件被主程序直接调用，不再是独立插件。\n' >&2
  exit 1
fi
if rg -n 'crontab|/etc/cron|systemctl[[:space:]]+(enable|start).*\.timer|docker[[:space:]]+run|podman[[:space:]]+run' \
  "$project_dir/deploy.sh" "$project_dir/install.sh" "$project_dir/xshell-install.sh" \
  "$project_dir/preflight.sh" "$project_dir/overwrite.sh" "$project_dir/scripts/socksctl" \
  "$project_dir/scripts/socks-doctor" "$project_dir/scripts/socks-safety"; then
  printf '核心程序引入了定时任务、容器或后台调度，违反轻量架构边界。\n' >&2
  exit 1
fi

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
  "$safety_test_dir/usr/local/lib/gost-socks" "$safety_test_dir/systemd"
cat >"$safety_test_dir/fakebin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  is-enabled) printf 'enabled\n' ;;
  is-active) printf 'active\n' ;;
esac
exit 0
EOF
chmod +x "$safety_test_dir/fakebin/systemctl"
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
chmod +x "$safety_test_dir/usr/local/lib/gost-socks/gost"
printf 'ExecStart=/fake/gost\n' >"$safety_test_dir/systemd/gost-socks.service"
safety_command=(env PATH="$safety_test_dir/fakebin:$PATH" \
  SOCKS_SAFETY_ROOT="$safety_test_dir/state" \
  SOCKS_CONFIG_DIR="$safety_test_dir/etc/gost-socks" \
  SOCKS_BINARY_DIR="$safety_test_dir/usr/local/lib/gost-socks" \
  SOCKS_SERVICE_FILE="$safety_test_dir/systemd/gost-socks.service" \
  "$project_dir/scripts/socks-safety")
transaction_snapshot=$("${safety_command[@]}" snapshot)
"${safety_command[@]}" verify "$transaction_snapshot" | grep -Fq '快照校验通过'
sed -i.bak 's/NODE_NAME=old/NODE_NAME=new/' "$safety_test_dir/etc/gost-socks/node.env"
rm -f -- "$safety_test_dir/etc/gost-socks/node.env.bak"
"${safety_command[@]}" promote "$transaction_snapshot" >/dev/null
grep -Fq 'NODE_NAME=old' "$safety_test_dir/state/snapshots/previous-good/config/node.env"
grep -Fq 'NODE_NAME=new' "$safety_test_dir/state/snapshots/last-good/config/node.env"
printf 'broken\n' >"$safety_test_dir/etc/gost-socks/node.env"
"${safety_command[@]}" restore "$safety_test_dir/state/snapshots/previous-good" >/dev/null
grep -Fq 'NODE_NAME=old' "$safety_test_dir/etc/gost-socks/node.env"
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
if grep -R -nE '130\.94\.102\.34|38\.92\.14\.4|SOCKS_PASSWORD=[^$]' \
  "$project_dir" --exclude-dir=.git --exclude='syntax.sh'; then
  printf '检测到疑似真实节点 IP 或明文密码。\n' >&2
  exit 1
fi

printf 'Shell 语法与帮助信息测试通过。\n'
