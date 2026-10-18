#!/bin/sh
set -eu

client="$1"
version="$2"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
conf="$test_dir/client.toml"

"$client" --version | grep -F " $version-"
for command in register ls run start stop unpublish; do
	"$client" --conf "$conf" --log-level info -v "$command" --help >/dev/null
done
"$client" register --help | grep -q -- '--auth'
"$client" register --help | grep -q -- '--acl'
"$client" register --help | grep -q -- '--header'

# Exercise the exact offline configuration commands used by cloudpub-run.
# Repeated setup must retain both the agent ID and its persisted HWID.
"$client" --conf "$conf" set token -- 'compatibility-test-not-a-real-token'
hwid="$("$client" --conf "$conf" get hwid)"
[ -n "$hwid" ]
"$client" --conf "$conf" set hwid "$hwid"
agent_id="$(grep '^agent_id[[:space:]]*=' "$conf")"
[ -n "$agent_id" ]
"$client" --conf "$conf" set token -- 'compatibility-test-not-a-real-token'
[ "$("$client" --conf "$conf" get hwid)" = "$hwid" ]
[ "$(grep '^agent_id[[:space:]]*=' "$conf")" = "$agent_id" ]
printf 'client CLI and persistent identity compatibility tests passed\n'
