#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

package_dir="$test_dir/package"
fake_bin="$test_dir/bin"
action_log="$test_dir/actions.log"
mkdir -p "$package_dir/scripts" "$fake_bin"
cp "$project_dir/xshell-install.sh" "$package_dir/"
printf '9.9.9\n' >"$package_dir/VERSION"

cat >"$fake_bin/id" <<'EOF'
#!/usr/bin/env bash
printf '0\n'
EOF
chmod +x "$fake_bin/id"

cat >"$package_dir/install.sh" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --version ]]; then
  tr -d '[:space:]' <"$(dirname -- "$0")/VERSION"
  exit 0
fi
printf 'install %s\n' "$*" >>"${SMART_ACTION_LOG:?}"
EOF

cat >"$package_dir/preflight.sh" <<'EOF'
#!/usr/bin/env bash
printf 'preflight %s\n' "$*" >>"${SMART_ACTION_LOG:?}"
exit "${SMART_PREFLIGHT_STATUS:?}"
EOF

cat >"$package_dir/overwrite.sh" <<'EOF'
#!/usr/bin/env bash
printf 'overwrite %s\n' "$*" >>"${SMART_ACTION_LOG:?}"
EOF

for helper in socks-refresh-ip socks-upgrade bbrctl; do
  printf '#!/usr/bin/env bash\n' >"$package_dir/scripts/$helper"
done
chmod +x "$package_dir/install.sh" "$package_dir/preflight.sh" \
  "$package_dir/overwrite.sh" "$package_dir/scripts/"*

run_entry() {
  env PATH="$fake_bin:$PATH" SMART_ACTION_LOG="$action_log" \
    SMART_PREFLIGHT_STATUS="$1" bash "$package_dir/xshell-install.sh" "${@:2}"
}

: >"$action_log"
run_entry 0 --port 32000 --no-bbr >/dev/null
grep -Fqx 'preflight --port 32000' "$action_log"
grep -Fqx 'install --port 32000 --no-bbr' "$action_log"
if grep -Fq 'overwrite' "$action_log"; then
  printf '全新安装状态不应进入旧协议迁移。\n' >&2
  exit 1
fi

: >"$action_log"
migration_output=$(run_entry 10 --port 32000)
grep -Fq '继续后会生成新的代理账号和密码' <<<"$migration_output"
grep -Fqx 'preflight --port 32000' "$action_log"
grep -Fqx 'overwrite --port 32000' "$action_log"
if grep -Fq 'install ' "$action_log"; then
  printf '可迁移状态必须由受控迁移器接管，不能直接安装。\n' >&2
  exit 1
fi

: >"$action_log"
blocked_output=""
if blocked_output=$(run_entry 2 --port 32000 2>&1); then
  printf '未知或混合状态本应停止智能安装。\n' >&2
  exit 1
fi
grep -Fq '不在安全自动处理白名单内' <<<"$blocked_output"
if grep -Eq '^(install|overwrite) ' "$action_log"; then
  printf '未知或混合状态不得修改代理服务。\n' >&2
  exit 1
fi
if grep -Fq -- '--overwrite' <<<"$blocked_output"; then
  printf '智能入口不应再要求新手复制第二条覆写命令。\n' >&2
  exit 1
fi

: >"$action_log"
run_entry 2 --port 32000 --overwrite >/dev/null
grep -Fqx 'overwrite --port 32000' "$action_log"

printf '智能安装状态分流测试通过。\n'
