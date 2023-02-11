# Build a filesystem from the cpm22 distro files, retro.asm BIOS, and some
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




all:: retro.img

retro.img: ../retro/retro.bin 
	rm -f retro.img
	mkfs.cpm -f z80-retro-2k-8m -b ../retro/retro.bin retro.img
	cpmcp -f z80-retro-2k-8m retro.img ../cpm22/filesystem/* 0:
	cpmcp -f z80-retro-2k-8m retro.img assemblers/sid/*.com 0:
	cpmcp -f z80-retro-2k-8m retro.img adventure/adv-B03/* 0:
	cpmcp -f z80-retro-2k-8m retro.img progs/tms9118/*.com 0:

local: retro.img
	if [ `ls -1 local/*/*/* 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f z80-retro-2k-8m retro.img local/*/*/* 0: ; \
	fi
	if [ `ls -1 progs/*/*.com 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f z80-retro-2k-8m retro.img progs/*/*.com 0: ; \
	fi
	if [ `ls -1 progs/*/*.bas 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f z80-retro-2k-8m retro.img progs/*/*.bas 0: ; \
	fi


# this is where the adventure game files came from:
adventure/cpm-advent.zip:
	wget -P adventure https://ifarchive.org/if-archive/games/cpm/cpm-advent.zip 


clean::
	rm -f retro.img 

burn: retro.img
	if [ `hostname` = "raspberrypi" ]; then \
		sudo dd if=retro.img of=/dev/sda1 bs=512; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi

lsimg: retro.img
	cpmls -f z80-retro-2k-8m retro.img 
