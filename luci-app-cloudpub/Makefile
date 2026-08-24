# LuCI support for the CloudPub client
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-cloudpub
PKG_VERSION:=1.2.0
PKG_RELEASE:=1

PKG_MAINTAINER:=CloudPub-OpenWRT
PKG_LICENSE:=Apache-2.0

LUCI_TITLE:=LuCI support for CloudPub client
LUCI_DESCRIPTION:=Web interface for CloudPub with automatic update checks and in-place updates.
LUCI_DEPENDS:=+cloudpub
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
