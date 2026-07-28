# LuCI support for the CloudPub client
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cloudpub
PKG_VERSION:=1.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=CloudPub-OpenWRT
PKG_LICENSE:=Apache-2.0

LUCI_TITLE:=LuCI support for CloudPub client
LUCI_DESCRIPTION:=Web interface for the CloudPub tunnel client: API token, publications, service status and in-place updates.
LUCI_DEPENDS:=+cloudpub
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
