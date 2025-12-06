# Build a filesystem from the cpm-2.2 distro files, retro.asm BIOS, and some
# sample downloads like adventure.
#
# To create an image with CP/M distro plus adventure:
# make drive.img
#
# To erase an SD card to prepare it for use:
# make blank-all-sd
#
# To copy the CP/M files onto drive A:
# make burn
#
#
# This is where the adventure game files came from:
# wget -P adventure https://ifarchive.org/if-archive/games/cpm/cpm-advent.zip 
#
# To list the files that are in the created image:
# make ls

# Put the 'all' target first so that it is THE default target.
# The :: means that more than one of the same target name is same as one big one.

all::

SUBDIRS=\
	assemblers\
	utils

# Include the detault and any local override rules
# Must set TOP before including Make.default

TOP=..
include $(TOP)/Make.rules
include $(TOP)/Make.default

.PHONY: burn blank-all-sd


all:: drive.img 

clean::
	rm -f drive.img

world:: clean all

drive.img: ../retro/retro.bin 
	rm -f $@
	mkfs.cpm -f $(DISKDEF) -b ../retro/retro.bin $@
	cpmcp -f $(DISKDEF) $@ ../cpm-2.2/filesystem/* 0:
	cpmcp -f $(DISKDEF) $@ assemblers/sid/*.com 0:
	cpmcp -f $(DISKDEF) $@ assemblers/slr/bin/* 0:
	cpmcp -f $(DISKDEF) $@ adventure/* 0:
	cpmcp -f $(DISKDEF) $@ utils/mbasic/*.com 0:
	cpmcp -f $(DISKDEF) $@ utils/xmodem80/*.com 0:
	cpmcp -f $(DISKDEF) $@ $(shell find utils/archive -maxdepth 1 -type f ! -name "Makefile" ! -name ".gitignore") 0:


burn: drive.img
	@ if [ `hostname` != "$(SD_HOSTNAME)" -o ! -b "$(SD_DEV)" ]; then\
		echo "\nWARNING: You are either NOT logged into $(SD_HOSTNAME) or there is no $(SD_DEV) mounted!\n"; \
		false; \
	fi
	sudo dd if=$< of=$(SD_DEV) bs=512 conv=fsync


# Erase ALL the CP/M drives on the SD card.  *** VERY DANGEROUS ***
# Write 16*8M of 0xE5 bytes into the CP/M partition on the SD card
blank-all-sd: 
	@ if [ `hostname` != "$(SD_HOSTNAME)" -o ! -b "$(SD_DEV)" ]; then\
		echo "\nWARNING: You are either NOT logged into $(SD_HOSTNAME) or there is no $(SD_DEV) mounted!\n"; \
		false; \
	fi
	LC_CTYPE=C tr '\0' '\345' < /dev/zero | sudo dd of=$(SD_DEV) bs=8M count=16 conv=fsync iflag=fullblock

ls:: drive.img 
	cpmls -f $(DISKDEF) $^
