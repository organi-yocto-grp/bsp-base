#!makefile

SHELL := /bin/bash

BUILD_ROOT ?= $(CURDIR)/build
SOURCE_ROOT ?= $(CURDIR)

DL_DIR ?=
SSTATE_DIR ?= $(BUILD_ROOT)/share/sstate-cache

MACHINE_BLACKLIST ?= $(strip $(shell if [ -e .machine.blacklist ]; then tr '\n' ' ' < .machine.blacklist; fi))

all: $(SSTATE_DIR)/.make.done
init: $(SSTATE_DIR)/.make.done

$(SSTATE_DIR)/.make.done:
	mkdir -p $(dir $@)
	touch $@

define add_machine
$1_init: $3_init
$1_init: $(BUILD_ROOT)/linda-$1/conf/local.conf
$(BUILD_ROOT)/linda-$1/conf/local.conf:
	mkdir -p $(BUILD_ROOT)/linda-$1
	MACHINE=$1 source ./setup-environment $(BUILD_ROOT)/linda-$1 $2
ifneq ($(DL_DIR),)
	sed -e "s,DL_DIR ?=.*,DL_DIR ?= '$(DL_DIR)',g" -i $$@
endif
	sed -e "s,SSTATE_DIR =.*,SSTATE_DIR = '$(SSTATE_DIR)',g" -i $$@

.PHONY : $1 $1_init
$1: $1_base $1_rootfs

.PHONY : $1_base $1_base_clean
$1_base: $(BUILD_ROOT)/linda-$1/.make.done
$(BUILD_ROOT)/linda-$1/.make.done:
	mkdir -p $$(dir $$@)
	MACHINE=$1 source ./setup-environment $$(dir $$@) $2 && bitbake u-boot pack-img autorock-image-dashboard;
	touch $$@ 
$1_base_clean:
	rm -f $(BUILD_ROOT)/linda-$1/.make.done

.PHONY : $1_rootfs $1_rootfs_clean
$1_rootfs: $(BUILD_ROOT)/linda-$3/.make.done.$1
$(BUILD_ROOT)/linda-$3/.make.done.$1:
	mkdir -p $$(dir $$@)
	source ./setup-environment $$(dir $$@) $2 && MACHINE=$1 bitbake autorock-image-core autorock-image-dev;
	touch $$@
$1_rootfs_clean:
	rm -f $(BUILD_ROOT)/linda-$3/.make.done.$1

.PHONY : $1_clean
$1_clean: $1_base_clean $1_rootfs_clean

ifeq ($2,imx6)
$1: $1_sdcard $1_sdcard_dev
$1_clean: $1_sdcard_clean

.PHONY : $1_sdcard
$1_sdcard: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard.tar.xz
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard.tar.xz: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard.img
	tar -cvJf $$@ -C $$(dir $$<) $$(notdir $$<)
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard.img: $(BUILD_ROOT)/linda-$1/.make.done $(BUILD_ROOT)/linda-$3/.make.done.$1
	dd if=/dev/zero of=$$@.tmp bs=1M count=256
	echo -e "o\nn\np\n1\n12288\n+58M\nn\np\n2\n131072\n\np\nw" | fdisk $$@.tmp
	echo -en "\x78\x56\x34\x12" | dd of=$$@.tmp conv=notrunc seek=440 bs=1
	dd if=$$(dir $$@)/SPL of=$$@.tmp bs=1K seek=1 conv=notrunc
	dd if=$$(dir $$@)/u-boot.img of=$$@.tmp bs=1K seek=64 conv=notrunc
	dd if=$$(dir $$@)/pack.img of=$$@.tmp bs=1M seek=1 conv=notrunc
	dd if=$$(dir $$@)/autorock-image-dashboard-$1.cpio.packimg of=$$@.tmp bs=1M seek=6 conv=notrunc
	dd if=$(BUILD_ROOT)/linda-$3/tmp/deploy/images/$1/autorock-image-core-$1.ext4 of=$$@.tmp bs=1M seek=64 conv=notrunc
	mv $$@.tmp $$@

.PHONY : $1_sdcard_dev
$1_sdcard_dev: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev.tar.xz
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev.tar.xz: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev.img
	tar -cvJf $$@ -C $$(dir $$<) $$(notdir $$<)
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev.img: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard.img
	cp $$< $$@.tmp
	dd if=/dev/zero of=$$@.tmp bs=1M seek=6 count=250 conv=notrunc
	dd if=$(BUILD_ROOT)/linda-$3/tmp/deploy/images/$1/autorock-image-dev-$1.ext4 of=$$@.tmp bs=1M seek=64 conv=notrunc
	mv $$@.tmp $$@

.PHONY : $1_rel $1_sdcard_rel $1_sdcard_dev_rel
$1_rel: $1_sdcard_rel $1_sdcard_dev_rel

$1_sdcard_rel: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-rel.tar.xz
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-rel.tar.xz: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-rel.img
	tar -cvJf $$@ -C $$(dir $$<) $$(notdir $$<)
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-rel.img: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard.img
	cp $$< $$@.tmp
	dd if=/dev/zero of=$$@.tmp bs=1K seek=1 count=6143 conv=notrunc
	mv $$@.tmp $$@

$1_sdcard_dev_rel: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev-rel.tar.xz
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev-rel.tar.xz: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev-rel.img
	tar -cvJf $$@ -C $$(dir $$<) $$(notdir $$<)
$(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev-rel.img: $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard-dev.img
	cp $$< $$@.tmp
	dd if=/dev/zero of=$$@.tmp bs=1K seek=1 count=6143 conv=notrunc
	mv $$@.tmp $$@

.PHONY : $1_sdcard_clean
$1_sdcard_clean:
	rm -f $(BUILD_ROOT)/linda-$1/tmp/deploy/images/$1/sdcard*
endif
endef

define add_machines
$2_init: $(BUILD_ROOT)/linda-$2/conf/local.conf
$(BUILD_ROOT)/linda-$2/conf/local.conf:
	mkdir -p $(BUILD_ROOT)/linda-$2
	source ./setup-environment $(BUILD_ROOT)/linda-$2 $1
ifneq ($(DL_DIR),)
	sed -e "s,DL_DIR ?=.*,DL_DIR ?= '$(DL_DIR)',g" -i $$@
endif
	sed -e "s,SSTATE_DIR =.*,SSTATE_DIR = '$(SSTATE_DIR)',g" -i $$@

machines := $$(shell ls sources/meta-$1-autorock/conf/machine/*.conf)
machines := $$(basename $$(notdir $$(machines)))
$$(foreach machine,$$(machines),$$(eval $$(call add_machine,$$(machine),$1,$2)))

machines := $$(filter-out $(MACHINE_BLACKLIST),$$(machines))
all: $$(machines)
init: $$(addsuffix _init,$$(machines))

.PHONY : $2_init $2_sdk $2_clean
all: $2_sdk
$2_sdk: $(BUILD_ROOT)/linda-$2/.make.done.$2
$(BUILD_ROOT)/linda-$2/.make.done.$2:
	mkdir -p $$(dir $$@)
	source ./setup-environment $$(dir $$@) $1 && bitbake meta-toolchain-qt5 && SDKMACHINE=x86_64 bitbake meta-toolchain-qt5;
	touch $$@
$2_clean:
	rm -f $(BUILD_ROOT)/linda-$2/.make.done.$2
endef

$(eval $(call add_machines,imx6,wisehmi))
$(eval $(call add_machines,sunxi,a20navi))

clean:
	rm -rf $(BUILD_ROOT)/linda-*/.make.done*

.PHONY : all init clean