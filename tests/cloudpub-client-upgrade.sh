#!/bin/sh
set -eu

previous="$1"
current="$2"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
conf="$test_dir/client.toml"

# Create the persistent identity with the previously shipped client, then
# perform the configuration setup used by cloudpub-run with the new client.
# All operations are offline and use an isolated, non-production token.
"$previous" --conf "$conf" set token -- 'upgrade-test-not-a-real-token'
hwid="$("$previous" --conf "$conf" get hwid)"
[ -n "$hwid" ]
"$previous" --conf "$conf" set hwid "$hwid"
agent_id="$(grep '^agent_id[[:space:]]*=' "$conf")"
[ -n "$agent_id" ]
for attempt in 1 2; do
	"$current" --conf "$conf" --log-level info set token -- 'upgrade-test-not-a-real-token'
	[ "$("$current" --conf "$conf" get hwid)" = "$hwid" ]
	[ "$(grep '^agent_id[[:space:]]*=' "$conf")" = "$agent_id" ]
done
printf 'client upgrade preserves agent_id and hwid\n'
