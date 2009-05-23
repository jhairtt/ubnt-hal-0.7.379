#
# Makefile for building madwifi driver with Ubiquiti Networks HAL & patches.
#
# Copyright (c) 2008 Ubiquiti Networks, Inc.
# 
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

MADWIFI_SNAPSHOT:=madwifi-dfs-r3319-20080201
MADWIFI_URL:=http://snapshots.madwifi.org/madwifi-dfs

SRC_FILE:=$(MADWIFI_SNAPSHOT).tar.gz
MADWIFI_FULL_URL:=$(MADWIFI_URL)/$(SRC_FILE)

EXTRA_PATCH_DIRS:=madwifi-dfs-r3319-20080201-openwrt

LC_ALL:=C
LANG:=C
export LC_ALL LANG

.PHONY: all clean unpack copy-hals build quilt

all: prepare-src build

dl/$(SRC_FILE):
	mkdir -p dl
	wget -c -t 0 $(MADWIFI_URL)/$(SRC_FILE) -O dl/$(SRC_FILE)

download: dl/$(SRC_FILE)

define Source/unpack
	rm -rf $2
	mkdir -p $2
	tar -C $2 -zxf $1
endef

define HAL/copy
	cp -a $(1)/*hal.o.uu $(2)/hal/public
endef


unpack: download
	$(call Source/unpack,dl/$(SRC_FILE),src)

copy-hals: unpack
	$(call HAL/copy,ubnt-hal,src/$(MADWIFI_SNAPSHOT))

define Source/patchall
	@for f in $2; do \
		echo -e "\nApplying: $$f"; \
		patch -p1 -E -d $1 < $$f; \
	done
endef

prepare-src: unpack copy-hals
	@echo -e "Main patches\n============\n"
	$(call Source/patchall,src/$(MADWIFI_SNAPSHOT),patches/$(MADWIFI_SNAPSHOT)/*.patch)
	@echo -e "\n\nExtra patches\n============\n"
	$(foreach extra,$(EXTRA_PATCH_DIRS),$(call Source/patchall,src/$(MADWIFI_SNAPSHOT),patches/$(extra)/*.patch))

build:
	make -C src/$(MADWIFI_SNAPSHOT)

define Quilt/patchall
	mkdir -p $(1)/patches
	for f in $$( cd $(2) && ls *.patch ); do (\
		echo -e "\nquilt-import: $$f"; \
		cp -f $(2)/$$f $(1); \
		cd $(1); \
		quilt import $$f; quilt push || exit 2; \
		rm -f $$f; \
	); done
endef

quilt: download
	$(call Source/unpack,dl/$(SRC_FILE),q)
	$(call HAL/copy,ubnt-hal,q/$(MADWIFI_SNAPSHOT))
	$(call Quilt/patchall,q/$(MADWIFI_SNAPSHOT),patches/$(MADWIFI_SNAPSHOT))
	$(foreach extra,$(EXTRA_PATCH_DIRS),$(call Quilt/patchall,q/$(MADWIFI_SNAPSHOT),patches/$(extra)))

clean:
	rm -rf src

distclean: clean
	rm -rf dl
