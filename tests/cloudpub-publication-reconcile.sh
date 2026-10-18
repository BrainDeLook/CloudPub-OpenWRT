#!/bin/sh
set -eu

eval "$(sed '/^if \[ "${1:-}" = "--apply-states" \]/,$d' cloudpub/files/cloudpub-run)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
STATE_FILE="$test_dir/publications.state"
DESIRED_GUIDS="$test_dir/desired"
CALLS="$test_dir/calls"
router=4494ad05-8771-4226-b544-0287037413b7
i2pd=77bd6b64-a993-4eb6-832b-5ea33089a5a0
new=874c7767-ff44-42c0-b72d-45c89fdd9bc8
TEST_SECTIONS='router i2pd'
TEST_LIST="online  $router [OpenWRT] http://192.168.1.1:80 -> https://router.cloudpub.ru:443
online  $i2pd [I2PD] http://192.168.1.1:7070 -> https://i2pd.cloudpub.ru:443"
config_get() {
	case "$3" in
		proto) eval "$1=http" ;;
		target)
			case "$2" in
				router) eval "$1=192.168.1.1" ;;
				i2pd) eval "$1=192.168.1.1:7070" ;;
				new) eval "$1=192.168.1.2:8123" ;;
			esac ;;
		*) eval "$1=" ;;
	esac
}
config_get_bool() { eval "$1=1"; }
config_foreach() { for section in $TEST_SECTIONS; do "$1" "$section"; done; }
clo() {
	printf '%s\n' "$*" >> "$CALLS"
	case "$1" in
		ls) printf '%s\n' "$TEST_LIST" ;;
		register) printf 'offline %s [New] http://192.168.1.2:8123 -> https://new.cloudpub.ru:443\n' "$new" ;;
	esac
}
log() { :; }
chmod() { :; }
: > "$STATE_FILE"
: > "$CALLS"

# Adopt existing domains with exact endpoint matching, including default port.
reconcile
[ "$(state_guid_for_target http 192.168.1.1)" = "$router" ]
[ "$(state_guid_for_target http 192.168.1.1:7070)" = "$i2pd" ]
! grep -Eq '^(register|unpublish) ' "$CALLS"

# A new invocation has no in-memory list but keeps the persistent state.
REGISTERED=
: > "$CALLS"
reconcile
! grep -Eq '^(register|unpublish) ' "$CALLS"

# Adding another path must not register or delete either existing service.
TEST_SECTIONS='router i2pd new'
: > "$CALLS"
reconcile
[ "$(grep -c '^register ' "$CALLS")" -eq 1 ]
grep -Fqx 'register http 192.168.1.2:8123' "$CALLS"
! grep -q '^unpublish ' "$CALLS"
[ "$(state_guid_for_target http 192.168.1.1)" = "$router" ]

# Removing I2PD must not remove the router on the same host.
TEST_LIST="$TEST_LIST
online  $new [New] http://192.168.1.2:8123 -> https://new.cloudpub.ru:443"
TEST_SECTIONS='router new'
: > "$CALLS"
reconcile
grep -Fqx "unpublish $i2pd" "$CALLS"
[ "$(grep -c '^unpublish ' "$CALLS")" -eq 1 ]
! grep -q '^register ' "$CALLS"
[ "$(state_guid_for_target http 192.168.1.1)" = "$router" ]
[ "$(state_guid_for_target http 192.168.1.2:8123)" = "$new" ]

# Failed discovery must never fall through to registration or deletion.
clo() { printf '%s\n' "$*" >> "$CALLS"; return 1; }
sleep() { :; }
: > "$CALLS"
if reconcile; then exit 1; fi
! grep -Eq '^(register|unpublish) ' "$CALLS"
[ "$(state_guid_for_target http 192.168.1.1)" = "$router" ]
printf 'publication restart/add/delete reconciliation tests passed\n'
