# Build a filesystem from the cpm22 distro files, retro.asm BIOS, and some
# sample downloads like adventure.

all: retro.img

retro.img: ../retro/retro.bin ../cpm22/filesystem/* adventure/adv-B03
	rm -f retro.img
	mkfs.cpm -f z80-retro-2k-8m -b ../retro/retro.bin retro.img
	cpmcp -f z80-retro-2k-8m retro.img ../cpm22/filesystem/* 0:
	cpmcp -f z80-retro-2k-8m retro.img adventure/adv-B03/* 0:

adventure/adv-B03: adventure/cpm-advent.zip
	unzip -d adventure adventure/cpm-advent.zip

adventure/cpm-advent.zip:
	wget -P adventure https://ifarchive.org/if-archive/games/cpm/cpm-advent.zip 

clean:
	rm -f retro.img 
	rm -rf `find adventure/* -name \*.zip -o -print`

burn: retro.img
	sudo dd if=retro.img of=/dev/sda1 bs=512

lsimg:
	cpmls -f z80-retro-2k-8m retro.img 
