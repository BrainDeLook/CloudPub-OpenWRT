# Licensing and third-party notices

## CloudPub OpenWrt integration

Copyright 2026 BrainDeLook and contributors.

Unless a file states otherwise, the original code and documentation of this
repository are licensed under Apache License 2.0. See LICENSE.

The exception is cloudpub/files/cloudpub-run, distributed under MPL-2.0 as
an OpenWrt adaptation of the Home Assistant add-on's publication reconciliation
script. These licenses apply to their respective files; this is not a choice
to relicense the MPL-covered file under Apache-2.0.

## Home Assistant CloudPub add-on

Project: https://github.com/black-roland/hassio-addon-cloudpub
Author: Black Roland and contributors.
Source used as the basis for the publication reconciliation flow:
https://github.com/black-roland/hassio-addon-cloudpub/blob/master/cloudpub-canary/rootfs/etc/s6-overlay/s6-rc.d/clo/run
License: Mozilla Public License 2.0 (MPL-2.0).
License text: LICENSES/MPL-2.0.txt in this repository;
MPL-2.0.txt alongside this notice in the installed cloudpub package.

The OpenWrt adaptation and subsequent modifications are maintained by
BrainDeLook and contributors. They replace HA-specific configuration and
supervision with UCI/procd and add persistent hardware identity, exact
endpoint/GUID associations and per-publication start/stop reconciliation.

The MPL-covered source, including these modifications, is available at:
https://github.com/BrainDeLook/CloudPub-OpenWRT/blob/main/cloudpub/files/cloudpub-run
For a particular released package, select its matching Git tag in that repository.
The cloudpub package includes an executable copy at /usr/libexec/cloudpub-run.

The luci-app-cloudpub package does not include this script; its cloudpub
dependency carries the MPL-covered file and the MPL license text.

## CloudPub client (clo)

Project and source: https://github.com/ermak-dev/cloudpub
Upstream license: Apache License 2.0.
Upstream license text:
https://github.com/ermak-dev/cloudpub/blob/master/LICENSE

The cloudpub package redistributes the official, unmodified clo binary from
https://cloudpub.ru/download/stable/ for the version selected by the build.
The Apache-2.0 text is included alongside this notice as LICENSE.

The upstream client and its bundled dependencies retain their respective
copyrights and license terms. This notice does not relicense them and does
not constitute an inventory of every dependency inside the upstream binary.

## OpenWrt and LuCI

OpenWrt and LuCI are separate runtime/build dependencies. Their existing code
and licenses are not replaced by the license of this integration.
CloudPub OpenWrt is an unofficial integration, not an endorsement by the
CloudPub, Home Assistant, OpenWrt or LuCI projects.
