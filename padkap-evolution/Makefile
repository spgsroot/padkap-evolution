include $(TOPDIR)/rules.mk

PKG_NAME:=padkap-evolution

PADKAP_EVOLUTION_SOURCE_VERSION:=$(or $(PADKAP_EVOLUTION_PACKAGE_VERSION),$(PADKAP_EVOLUTION_VERSION))
PADKAP_EVOLUTION_HAS_RELEASE_VERSION:=$(if $(filter dev,$(PADKAP_EVOLUTION_SOURCE_VERSION)),,$(PADKAP_EVOLUTION_SOURCE_VERSION))
PADKAP_EVOLUTION_COMPILED_VERSION:=$(if $(PADKAP_EVOLUTION_HAS_RELEASE_VERSION),$(PADKAP_EVOLUTION_SOURCE_VERSION),$(or $(PADKAP_EVOLUTION_SOURCE_VERSION),dev))
PADKAP_EVOLUTION_RELEASE_VERSION_VALID:=$(if $(PADKAP_EVOLUTION_HAS_RELEASE_VERSION),$(shell printf '%s\n' '$(PADKAP_EVOLUTION_SOURCE_VERSION)' | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' && printf '1'),1)

ifeq ($(PADKAP_EVOLUTION_RELEASE_VERSION_VALID),)
$(error PADKAP_EVOLUTION_PACKAGE_VERSION and PADKAP_EVOLUTION_VERSION must use x.y.z format)
endif

PKG_VERSION:=$(or $(PADKAP_EVOLUTION_HAS_RELEASE_VERSION),0.0.0)
PKG_RELEASE:=

PKG_MAINTAINER:=spgsroot <spgsroot@users.noreply.github.com>
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/padkap-evolution
	SECTION:=net
	CATEGORY:=Network
	DEPENDS:=+ca-bundle +kmod-inet-diag +kmod-netlink-diag +kmod-tun +curl +ucode +ucode-mod-fs +ucode-mod-uci +kmod-nft-tproxy +coreutils-base64 +bind-dig +nftables +kmod-nft-nat +ip-full
	CONFLICTS:=https-dns-proxy nextdns luci-app-passwall luci-app-passwall2
	TITLE:=Padkap Evolution backend service
	URL:=https://github.com/spgsroot/padkap-evolution
	PKGARCH:=all
endef

define Package/padkap-evolution/description
	Rule-based Padkap Evolution backend with hybrid sing-box + zapret orchestration
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/padkap-evolution/prerm
#!/usr/bin/ucode

if (getenv("IPKG_INSTROOT") == null || getenv("IPKG_INSTROOT") == "")
	system("/usr/bin/padkap-evolution package_prerm " + (ARGV[0] || "") + " >/dev/null 2>&1");

exit(0);
endef

define Package/padkap-evolution/postinst
#!/bin/sh

[ -n "$${IPKG_INSTROOT}" ] && exit 0
PADKAP_EVOLUTION_LIB=/usr/lib/padkap-evolution ucode -L /usr/lib/padkap-evolution /usr/lib/padkap-evolution/config/migration.uc migrate || exit $$?
/usr/bin/padkap-evolution package_postinst
endef

define Package/padkap-evolution/conffiles
/etc/config/padkap-evolution
endef

define Package/padkap-evolution/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/padkap-evolution $(1)/etc/init.d/padkap-evolution

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/padkap-evolution $(1)/etc/config/padkap-evolution

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/padkap-evolution $(1)/usr/bin/padkap-evolution

	$(INSTALL_DIR) $(1)/usr/lib/padkap-evolution
	$(CP) ./files/usr/lib/. $(1)/usr/lib/padkap-evolution/

	sed -i -e 's/__COMPILED_VERSION_VARIABLE__/$(PADKAP_EVOLUTION_COMPILED_VERSION)/g' $(1)/usr/lib/padkap-evolution/core/constants.uc
endef

$(eval $(call BuildPackage,padkap-evolution))
