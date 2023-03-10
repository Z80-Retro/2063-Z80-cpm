# Build a filesystem from the cpm-2.2 distro files, retro.asm BIOS, and some
# sample downloads like adventure.
#
# To create an image with CP/M distro plus adventure:
# make retro.img
#
# To create an image with CP/M distro plus adventure and local additions:
# make local
#
# To list the files that are in the created image:
# make lsimg

SUBDIRS=\
	progs/tty \
	progs/example \
	progs/tms9118
NOTYET=\
	progs/nhacp

CLEAN_DIRS=$(SUBDIRS:%=clean-%)
ALL_DIRS=$(SUBDIRS:%=all-%)

.PHONY: all clean $(CLEAN_DIRS) $(ALL_DIRS)

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


all:: retro.img

retro.img: ../retro/retro.bin 
	rm -f retro.img
	mkfs.cpm -f $(DISKDEF) -b ../retro/retro.bin retro.img
	cpmcp -f $(DISKDEF) retro.img ../cpm-2.2/filesystem/* 0:
	cpmcp -f $(DISKDEF) retro.img assemblers/sid/*.com 0:
	cpmcp -f $(DISKDEF) retro.img adventure/* 0:
	cpmcp -f $(DISKDEF) retro.img progs/*/*.com 0:

local: retro.img
	if [ `ls -1 local/*/*/* 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f $(DISKDEF) retro.img local/*/*/* 0: ; \
	fi
	if [ `ls -1 progs/*/*.com 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f $(DISKDEF) retro.img progs/*/*.com 0: ; \
	fi
	if [ `ls -1 progs/*/*.bas 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f $(DISKDEF) retro.img progs/*/*.bas 0: ; \
	fi


# this is where the adventure game files came from:
adventure/cpm-advent.zip:
	wget -P adventure https://ifarchive.org/if-archive/games/cpm/cpm-advent.zip 


clean::
	rm -f retro.img 


# For normal use on a plain Raspberry PI
SD_DEV=sda1

burn: retro.img
	if [ `hostname` = "raspberrypi" ]; then\
		sudo dd if=retro.img of=/dev/$(SD_DEV) bs=512; \
	elif [ `hostname` = "x570.winans.org" ]; then \
		sudo dd if=retro.img of=/dev/sdc1 bs=512; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi

# Erase ALL the CP/M drives on the SD card.  *** VERY DANGEROUS ***
# Write 16*8M of 0xE5 bytes into the CP/M partition on the SD card
blank-all-sd: retro.img
	if [ `hostname` = "raspberrypi" ]; then \
		LC_CTYPE=C tr '\0' '\345' < /dev/zero | sudo dd of=/dev/$(SD_DEV) bs=8M count=16 conv=fsync iflag=fullblock ; \
	elif [ `hostname` = "x570.winans.org" ]; then \
		LC_CTYPE=C tr '\0' '\345' < /dev/zero | sudo dd of=/dev/sdc1 bs=8M count=16 conv=fsync iflag=fullblock ; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi


lsimg: retro.img
	cpmls -f $(DISKDEF) retro.img 
