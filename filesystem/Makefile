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


all: retro.img

retro.img: ../retro/retro.bin ../cpm22/filesystem/* adventure/adv-B03
	rm -f retro.img
	mkfs.cpm -f z80-retro-2k-8m -b ../retro/retro.bin retro.img
	cpmcp -f z80-retro-2k-8m retro.img ../cpm22/filesystem/* 0:
	cpmcp -f z80-retro-2k-8m retro.img adventure/adv-B03/* 0:

tms9118: retro.img
	if [ `ls -1 progs/tms9118/*.com 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f z80-retro-2k-8m retro.img progs/tms9118/*.com 0: ; \
	fi

assemblers: retro.img
	if [ `ls -1 assemblers/*/* 2>/dev/null | wc -l` -gt 0 ]; then\
		cpmcp -f z80-retro-2k-8m retro.img assemblers/*/* 0: ; \
	fi

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


world: clean all

adventure/adv-B03: adventure/cpm-advent.zip
	unzip -d adventure adventure/cpm-advent.zip

adventure/cpm-advent.zip:
	wget -P adventure https://ifarchive.org/if-archive/games/cpm/cpm-advent.zip 

clean:
	rm -f retro.img 
	rm -rf `find adventure/* -name \*.zip -o -print`

burn: retro.img
	if [ `hostname` = "raspberrypi" ]; then \
		sudo dd if=retro.img of=/dev/sda1 bs=512; \
	else \
		echo "WARNING: If you are NOT on a raspberrypi then this may destroy your filesystem!"; \
	fi

lsimg: retro.img
	cpmls -f z80-retro-2k-8m retro.img 
