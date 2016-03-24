#
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=bonding
PKG_RELEASE:=1

PKG_LICENSE:=GPLv2 GPLv2+
PKG_LICENSE_FILES:=

include $(INCLUDE_DIR)/package.mk

define Package/bonding
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=morewifi system bonding
  DEPENDS:=+libubox +libblobmsg-json +libiptc +libjson-c +libmcrypt +libuclient +libip4tc +libubus
endef


define Package/bonding/description
 This package support link-aggregation for morewifi system.
endef


define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/bonding/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/bonding.lua $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/bonding.init $(1)/etc/init.d/bonding
	$(INSTALL_DIR) $(1)/etc/config/
	$(INSTALL_BIN) ./files/bonding $(1)/etc/config/bonding
endef


$(eval $(call BuildPackage,bonding))

