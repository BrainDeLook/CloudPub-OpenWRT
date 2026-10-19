#!/bin/sh
set -eu

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

check_package() {
	local archive="$1" name="$2" license="$3" dir
	dir="$test_dir/$name"
	mkdir -p "$dir"
	tar -xzf "$archive" -C "$dir"
	tar -xzf "$dir/data.tar.gz" -C "$dir"
	tar -xzf "$dir/control.tar.gz" -C "$dir"
	grep -Fqx "License: $license" "$dir/control"
	cmp LICENSE "$dir/usr/share/licenses/$name/LICENSE"
	cmp THIRD_PARTY_NOTICES.md "$dir/usr/share/licenses/$name/THIRD_PARTY_NOTICES.md"
	if [ "$name" = cloudpub ]; then
		cmp LICENSES/MPL-2.0.txt "$dir/usr/share/licenses/$name/MPL-2.0.txt"
		grep -Fq '# SPDX-License-Identifier: MPL-2.0' "$dir/usr/libexec/cloudpub-run"
	fi
}

# The SDK's LuCI install copies root/ directly, independently of build.sh.
cmp LICENSE luci-app-cloudpub/root/usr/share/licenses/luci-app-cloudpub/LICENSE
cmp THIRD_PARTY_NOTICES.md luci-app-cloudpub/root/usr/share/licenses/luci-app-cloudpub/THIRD_PARTY_NOTICES.md
check_package "$1" cloudpub 'Apache-2.0 AND MPL-2.0'
check_package "$2" luci-app-cloudpub Apache-2.0
printf 'package license documents and metadata checks passed\n'
