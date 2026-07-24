#
# CloudPub client (clo) for OpenWrt
#
# The client is distributed as a prebuilt static binary from cloudpub.ru,
# this package downloads and installs the binary matching the target
# architecture.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=cloudpub
PKG_VERSION:=3.2.2
PKG_RELEASE:=1

CLO_ARCH:=

ifeq ($(ARCH),x86_64)
  CLO_ARCH:=x86_64
else ifeq ($(ARCH),aarch64)
  CLO_ARCH:=aarch64
else ifeq ($(ARCH),mipsel)
  CLO_ARCH:=mipsel
else ifeq ($(ARCH),arm)
  # ARMv5 CPUs need the armv5te build, everything newer uses the ARMv6+ build
  ifneq ($(filter arm926ej-s fa526 xscale,$(CONFIG_CPU_TYPE)),)
    CLO_ARCH:=armv5te
  else
    CLO_ARCH:=arm
  endif
endif

PKG_SOURCE:=clo-$(PKG_VERSION)-stable-linux-$(CLO_ARCH).tar.gz
PKG_SOURCE_URL:=https://cloudpub.ru/download/stable
PKG_HASH:=skip

PKG_MAINTAINER:=CloudPub-OpenWRT
PKG_LICENSE:=Apache-2.0

include $(INCLUDE_DIR)/package.mk

define Package/cloudpub
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=CloudPub tunnel client (clo)
  URL:=https://cloudpub.ru
  DEPENDS:=@(aarch64||arm||mipsel||x86_64)
endef

define Package/cloudpub/description
  CloudPub is a service for publishing local resources to the Internet
  through a secure tunnel (a Russian alternative to ngrok).
  This package installs the clo command line client, a UCI configuration
  and a procd init script.
endef

define Package/cloudpub/conffiles
/etc/config/cloudpub
/etc/cloudpub/
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/cloudpub/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $$$$(find $(PKG_BUILD_DIR) -type f -name clo | head -n1) $(1)/usr/bin/clo
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/cloudpub.init $(1)/etc/init.d/cloudpub
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/cloudpub.config $(1)/etc/config/cloudpub
endef

$(eval $(call BuildPackage,cloudpub))
