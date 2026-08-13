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
timeout_wrapper="$test_dir/timeout"
timeout_failure="$test_dir/timeout-failure"
fake_bin="$test_dir/fakebin"
mkdir -p "$config_dir" "$repository_dir/scripts" "$fake_bin"

cat >"$config_dir/node.env" <<'EOF'
NODE_NAME=fixture-node
PUBLIC_IP=192.0.2.10
SOCKS_PORT=31080
SOCKS_USERNAME=fixture_user
SOCKS_PASSWORD=fixture_password_123456
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
chmod +x "$timeout_wrapper" "$timeout_failure"
cat >"$fake_bin/flock" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$fake_bin/flock"

printf '1.9.2\n' >"$repository_dir/VERSION"
printf '# fixture module\n' >"$repository_dir/scripts/socks-upgrade"
cat >"$repository_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${1:-} != --version ]] || { printf '1.9.2\n'; exit 0; }
config_dir=${SOCKS_CONFIG_DIR:?}
env_file="$config_dir/node.env"
port=""
preserve_node=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) port=${2:-}; shift 2 ;;
    --preserve-node) preserve_node=true; shift ;;
    *) printf 'fixture installer received unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done
[[ $preserve_node == true ]] || { printf 'fixture installer requires preserve mode\n' >&2; exit 1; }
existing_port=$(awk -F= '$1 == "SOCKS_PORT" {print $2}' "$env_file")
[[ $port == "$existing_port" ]] || { printf 'fixture port changed\n' >&2; exit 1; }
awk -F= '$1 == "TOOL_VERSION" {print "TOOL_VERSION=1.9.2"; found=1; next} \
  {print} END {if (!found) print "TOOL_VERSION=1.9.2"}' \
  "$env_file" >"$env_file.next"
mv "$env_file.next" "$env_file"
EOF
chmod +x "$repository_dir/install.sh"

git -C "$repository_dir" init -q
git -C "$repository_dir" add VERSION install.sh scripts/socks-upgrade
git -C "$repository_dir" -c user.name='Release Test' -c user.email='release-test@example.invalid' \
  commit -q -m 'fixture v1.9.2'
git -C "$repository_dir" tag v1.9.2

upgrade_environment=(
  "PATH=$fake_bin:$PATH"
  "SOCKS_CONFIG_DIR=$config_dir"
  "SOCKS_SERVICE_FILE=$service_file"
  "SOCKS_LOCK_FILE=$lock_file"
  "SOCKS_REPOSITORY_URL=$repository_dir"
  "SOCKS_TIMEOUT_BIN=$timeout_wrapper"
)

before_identity=$(awk -F= '$1 != "TOOL_VERSION" {print}' "$config_dir/node.env")
upgrade_output=$(printf 'UPGRADE-v1.9.2\n' | env "${upgrade_environment[@]}" \
  "$project_dir/scripts/socks-upgrade" v1.9.2 2>&1)
after_identity=$(awk -F= '$1 != "TOOL_VERSION" {print}' "$config_dir/node.env")

grep -Fq '安全升级完成：早期版本 → v1.9.2' <<<"$upgrade_output"
grep -Fq 'TOOL_VERSION=1.9.2' "$config_dir/node.env"
[[ $before_identity == "$after_identity" ]] || {
  printf '完整升级流程改变了节点身份、IP、端口或凭据。\n' >&2
  exit 1
}
if grep -Fq 'fixture_password_123456' <<<"$upgrade_output"; then
  printf '完整升级流程输出了代理密码。\n' >&2
  exit 1
fi

grep -v '^TOOL_VERSION=' "$config_dir/node.env" >"$config_dir/node.env.next"
mv "$config_dir/node.env.next" "$config_dir/node.env"
timeout_output=""
if timeout_output=$(env "${upgrade_environment[@]}" SOCKS_TIMEOUT_BIN="$timeout_failure" \
  "$project_dir/scripts/socks-upgrade" --check v1.9.2 2>&1); then
  printf '标签查询超时后升级器本应停止。\n' >&2
  exit 1
fi
grep -Fq '查询稳定标签超时或失败' <<<"$timeout_output"
if grep -q '^TOOL_VERSION=' "$config_dir/node.env"; then
  printf '标签查询超时后升级器修改了早期节点的版本记录。\n' >&2
  exit 1
fi

printf '完整升级流程、凭据保留和超时停止测试通过。\n'
