include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-padkap-evolution

PADKAP_EVOLUTION_SOURCE_VERSION:=$(or $(PADKAP_EVOLUTION_PACKAGE_VERSION),$(PADKAP_EVOLUTION_VERSION))
PADKAP_EVOLUTION_HAS_RELEASE_VERSION:=$(if $(filter dev,$(PADKAP_EVOLUTION_SOURCE_VERSION)),,$(PADKAP_EVOLUTION_SOURCE_VERSION))
PADKAP_EVOLUTION_COMPILED_VERSION:=$(if $(PADKAP_EVOLUTION_HAS_RELEASE_VERSION),$(PADKAP_EVOLUTION_SOURCE_VERSION),$(or $(PADKAP_EVOLUTION_SOURCE_VERSION),dev))
PADKAP_EVOLUTION_RELEASE_VERSION_VALID:=$(if $(PADKAP_EVOLUTION_HAS_RELEASE_VERSION),$(shell printf '%s\n' '$(PADKAP_EVOLUTION_SOURCE_VERSION)' | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' && printf '1'),1)

ifeq ($(PADKAP_EVOLUTION_RELEASE_VERSION_VALID),)
$(error PADKAP_EVOLUTION_PACKAGE_VERSION and PADKAP_EVOLUTION_VERSION must use x.y.z format)
endif

PKG_VERSION:=$(or $(PADKAP_EVOLUTION_HAS_RELEASE_VERSION),0.0.0)
PKG_RELEASE:=
PKG_PO_VERSION:=$(PKG_VERSION)

LUCI_TITLE:=LuCI Padkap Evolution app
LUCI_DEPENDS:=+luci-base +padkap-evolution
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English
LUCI_MAINTAINER:=spgsroot <spgsroot@users.noreply.github.com>
LUCI_DESCRIPTION:=Rule-based Padkap Evolution LuCI app with hybrid sing-box + zapret orchestration
LUCI_MINIFY_JS:=0

PKG_LICENSE:=GPL-2.0-or-later
LUCI_LANGUAGES:=en ru

define Build/Prepare/$(PKG_NAME)
	sed -i -e 's/__COMPILED_VERSION_VARIABLE__/$(PADKAP_EVOLUTION_COMPILED_VERSION)/g' $(PKG_BUILD_DIR)/htdocs/luci-static/resources/view/padkap-evolution/main.js
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
