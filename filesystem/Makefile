# Build a filesystem from the cpm-2.2 distro files, retro.asm BIOS, and some
# sample downloads like adventure.
#
# To create an image with CP/M distro plus adventure:
# make drive-0.img
#
# To create an image of files for drive B: with local additions:
# make drive-1.img
#
# To erase an SD card to prepare it for use:
# make blank-all-sd
#
# To copy the CP/M files onto drive A:
# make burn
#
# To copy the local files onto drive B:
# make burn-b
#
#
# This is where the adventure game files came from:
# wget -P adventure https://ifarchive.org/if-archive/games/cpm/cpm-advent.zip 
#
# To list the files that are in the created image:
# make lsimg


# Make 'all' first so that it is THE default target.
# The :: means that more than one of the same target name is same as one big one.

all::

# optionally include rules from a local file:
-include Make.local




SUBDIRS+=\
	progs/tty \
	progs/example \
	progs/tms9118

CLEAN_DIRS=$(SUBDIRS:%=clean-%)
ALL_DIRS=$(SUBDIRS:%=all-%)

.PHONY: all clean $(CLEAN_DIRS) $(ALL_DIRS) burn burn-b blank-all-sd

all:: $(ALL_DIRS)

clean:: $(CLEAN_DIRS)

world:: clean all

$(ALL_DIRS):
	$(MAKE) -C $(@:all-%=%) all

$(CLEAN_DIRS):
	$(MAKE) -C $(@:clean-%=%) clean


#DISKDEF=z80-retro-2k-8m
DISKDEF=z80-retro-8k-8m
#DISKDEF=z80-retro-16k-8m


all:: drive-0.img drive-1.img

drive-0.img: ../retro/retro.bin 
	rm -f $@
	mkfs.cpm -f $(DISKDEF) -b ../retro/retro.bin $@
	cpmcp -f $(DISKDEF) $@ ../cpm-2.2/filesystem/* 0:
	cpmcp -f $(DISKDEF) $@ assemblers/sid/*.com 0:
	cpmcp -f $(DISKDEF) $@ adventure/* 0:

drive-1.img:
	rm -f $@
	mkfs.cpm -f $(DISKDEF) -b ../retro/retro.bin $@
	if [ `ls -1 local/*/*/* 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f $(DISKDEF) $@ local/*/*/* 0: ; \
	fi
	if [ `ls -1 progs/*/*.com 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f $(DISKDEF) $@ progs/*/*.com 0: ; \
	fi
	if [ `ls -1 progs/*/*.bas 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f $(DISKDEF) $@ progs/*/*.bas 0: ; \
	fi


clean::
	rm -f drive-0.img drive-1.img


# For normal use on a plain Raspberry PI
SD_DEV=sda1

burn: drive-0.img
	if [ `hostname` = "raspberrypi" ]; then\
		sudo dd if=$< of=/dev/$(SD_DEV) bs=512; conv=fsync; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi

burn-b: drive-1.img
	if [ `hostname` = "raspberrypi" ]; then\
		sudo dd if=$< of=/dev/$(SD_DEV) bs=512 seek=01x16384 conv=fsync; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi

# Erase ALL the CP/M drives on the SD card.  *** VERY DANGEROUS ***
# Write 16*8M of 0xE5 bytes into the CP/M partition on the SD card
blank-all-sd: 
	if [ `hostname` = "raspberrypi" ]; then \
		LC_CTYPE=C tr '\0' '\345' < /dev/zero | sudo dd of=/dev/$(SD_DEV) bs=8M count=16 conv=fsync iflag=fullblock ; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi


ls:: drive-0.img drive-1.img
	cpmls -f $(DISKDEF) drive-0.img 
	cpmls -f $(DISKDEF) drive-1.img 


