#!makefile

SHELL := /bin/bash

DL_DIR ?=
SSTATE_DIR ?= $(CURDIR)/build/share/sstate-cache

all: build/share/sstate-cache/.make.done
init: build/share/sstate-cache/.make.done

build/share/sstate-cache/.make.done:
	mkdir -p $(dir $@)
	touch $@

define add_machine
init: build/linda-$1/conf/local.conf
build/linda-$1/conf/local.conf:
	mkdir -p build/linda-$1
	MACHINE=$1 source ./setup-environment build/linda-$1 $2
ifneq ($(DL_DIR),)
	sed -e "s,DL_DIR ?=.*,DL_DIR ?= '$(DL_DIR)',g" -i $$@
endif
	sed -e "s,SSTATE_DIR =.*,SSTATE_DIR = '$(SSTATE_DIR)',g" -i $$@

.PHONY : $1
all: $1
$1: $1_base $1_rootfs

.PHONY : $1_base $1_base_clean
$1_base: build/linda-$1/.make.done
build/linda-$1/.make.done:
	mkdir -p $$(dir $$@)
	MACHINE=$1 source ./setup-environment $$(dir $$@) $2 && bitbake u-boot pack-img autorock-image-dashboard;
	touch $$@ 
$1_base_clean:
	rm -f build/linda-$1/.make.done

.PHONY : $1_rootfs $1_rootfs_clean
$1_rootfs: build/linda-$3/.make.done.$1
build/linda-$3/.make.done.$1:
	mkdir -p $$(dir $$@)
	source ./setup-environment $$(dir $$@) $2 && MACHINE=$1 bitbake autorock-image-core autorock-image-dev;
	touch $$@
$1_rootfs_clean:
	rm -f build/linda-$3/.make.done.$1

.PHONY : $1_clean
$1_clean: $1_base_clean $1_rootfs_clean

ifeq ($2,imx6)
$1: $1_sdcard $1_sdcard_dev

.PHONY : $1_sdcard
$1_sdcard: build/linda-$1/tmp/deploy/images/$1/sdcard.img
build/linda-$1/tmp/deploy/images/$1/sdcard.img: build/linda-$1/.make.done build/linda-$3/.make.done.$1
	dd if=/dev/zero of=$$@.tmp bs=1M count=256
	echo -e "o\nn\np\n1\n12288\n+58M\nn\np\n2\n131072\n\np\nw" | fdisk $$@.tmp
	dd if=$$(dir $$@)/SPL of=$$@.tmp bs=1K seek=1
	dd if=$$(dir $$@)/u-boot.img of=$$@.tmp bs=1K seek=64
	dd if=$$(dir $$@)/pack.img of=$$@.tmp bs=1M seek=1
	dd if=$$(dir $$@)/autorock-image-dashboard-$1.cpio.packimg of=$$@.tmp bs=1M seek=6
	dd if=build/linda-$3/tmp/deploy/images/$1/autorock-image-core-$1.ext4 of=$$@.tmp bs=1M seek=64
	mv $$@.tmp $$@

.PHONY : $1_sdcard_dev
$1_sdcard_dev: build/linda-$1/tmp/deploy/images/$1/sdcard-dev.img
build/linda-$1/tmp/deploy/images/$1/sdcard-dev.img: build/linda-$1/tmp/deploy/images/$1/sdcard.img
	cp $$< $$@.tmp
	dd if=build/linda-$3/tmp/deploy/images/$1/autorock-image-dev-$1.ext4 of=$$@.tmp bs=1M seek=64
	mv $$@.tmp $$@
endif
endef

define add_machines
init: build/linda-$2/conf/local.conf
build/linda-$2/conf/local.conf:
	mkdir -p build/linda-$2
	source ./setup-environment build/linda-$2 $1
ifneq ($(DL_DIR),)
	sed -e "s,DL_DIR ?=.*,DL_DIR ?= '$(DL_DIR)',g" -i $$@
endif
	sed -e "s,SSTATE_DIR =.*,SSTATE_DIR = '$(SSTATE_DIR)',g" -i $$@

machines := $$(shell ls sources/meta-$1-autorock/conf/machine/*.conf)
machines := $$(basename $$(notdir $$(machines)))
$$(foreach machine,$$(machines),$$(eval $$(call add_machine,$$(machine),$1,$2)))

.PHONY : $2_sdk $2_clean
all: $2_sdk
$2_sdk: build/linda-$2/.make.done.$2
build/linda-$2/.make.done.$2:
	mkdir -p $$(dir $$@)
	source ./setup-environment $$(dir $$@) $1 && bitbake meta-toolchain-qt5 && SDKMACHINE=x86_64 bitbake meta-toolchain-qt5;
	touch $$@
$2_clean:
	rm -f build/linda-$2/.make.done.$2
endef

$(eval $(call add_machines,imx6,wisehmi))
$(eval $(call add_machines,sunxi,a20navi))

clean:
	rm -rf build/linda-*/.make.done*

.PHONY : all init clean