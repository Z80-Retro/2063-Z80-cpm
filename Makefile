all::

SUBDIRS=\
	boot \
	retro \
	tests \
	hello \
	filesystem

TOP=.
include $(TOP)/Make.rules

REL_FILES=\
	LICENSE \
	Makefile \
	Make.default \
	README-SD.md \
	README.md \
	boot \
	cpm-2.2 \
	doc \
	hello \
	lib \
	libretro \
	libnouveau \
	retro \
	tests \
	filesystem/Makefile \
	filesystem/README.md \
	filesystem/diskdefs \
	filesystem/drive.img \
	filesystem/assemblers \
	filesystem/utils \


release:
	rm -f 2063-Z80-cpm.zip
	zip -r 2063-Z80-cpm.zip $(REL_FILES)
