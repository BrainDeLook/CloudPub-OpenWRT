#!/bin/sh
set -eu

# Load function definitions without starting the real CloudPub agent.
eval "$(sed '/^if \[ "${1:-}" = "--apply-states" \]/,$d' cloudpub/files/cloudpub-run)"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
STATE_FILE="$test_dir/publications.state"
DESIRED_GUIDS="$test_dir/desired"
CALLS="$test_dir/calls"
guid=4494ad05-8771-4226-b544-0287037413b7
TEST_ENABLED=0
TEST_AUTH=none
REGISTERED="online  $guid [OpenWRT] http://192.168.1.1:80 -> https://example.cloudpub.ru:443"
printf 'http\t192.168.1.1\t%s\n' "$guid" > "$STATE_FILE"
: > "$DESIRED_GUIDS"
: > "$CALLS"

config_get() {
	case "$3" in
		proto) eval "$1=http" ;;
		target) eval "$1=192.168.1.1" ;;
		auth) eval "$1=\$TEST_AUTH" ;;
		*) eval "$1=" ;;
	esac
}
config_get_bool() { eval "$1=\$TEST_ENABLED"; }
clo() { printf '%s\n' "$*" >> "$CALLS"; }
log() { :; }
chmod() { :; }

# Disabling must retain the old GUID and never unpublish it.
register_publication section
remove_deleted_publications
grep -Fqx "$guid" "$DESIRED_GUIDS"
grep -Fq "$guid" "$STATE_FILE"
[ ! -s "$CALLS" ]

STOP_SUCCEEDED=
STATE_PENDING=0
apply_publication_state section
grep -Fqx "stop $guid" "$CALLS"
[ "$STATE_PENDING" -eq 1 ]

# Once the agent reports it stopped, do not issue a second stop.
REGISTERED="stopped $guid [OpenWRT] http://192.168.1.1:80 -> https://example.cloudpub.ru:443"
STATE_PENDING=0
apply_publication_state section
[ "$STATE_PENDING" -eq 0 ]
[ "$(wc -l < "$CALLS")" -eq 1 ]

# Enabling the same section resumes the same GUID rather than registering it.
TEST_ENABLED=1
STATE_PENDING=0
apply_publication_state section
grep -Fqx "start $guid" "$CALLS"
register_publication section
! grep -q '^register ' "$CALLS"

# Actual deletion is still allowed to remove the publication.
REGISTERED="stopped $guid [OpenWRT] http://192.168.1.1:80 -> https://example.cloudpub.ru:443"
: > "$DESIRED_GUIDS"
remove_deleted_publications
grep -Fqx "unpublish $guid" "$CALLS"

# Authentication is passed when the service is first registered.
REGISTERED=
: > "$STATE_FILE"
TEST_AUTH=basic
register_publication section
grep -Fqx 'register --auth basic http 192.168.1.1' "$CALLS"
printf 'publication toggle regression tests passed\n'
