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
  "$project_dir/scripts/release-check.sh"
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

grep -q 'port=31080' "$project_dir/deploy.sh"
grep -q 'readonly GOST_VERSION="3.2.6"' "$project_dir/install.sh"
grep -q 'node_name=$public_ip' "$project_dir/install.sh"
grep -q 'PUBLIC_IP=$public_ip' "$project_dir/install.sh"
grep -q '20.04|22.04|24.04' "$project_dir/preflight.sh"
grep -q '/root/gost-socks-backups' "$project_dir/overwrite.sh"
grep -q 'systemctl disable --now sing-box' "$project_dir/overwrite.sh"
grep -q 'trap rollback ERR' "$project_dir/overwrite.sh"

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
