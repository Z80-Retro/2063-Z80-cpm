SUBDIRS=\
	boot \
	tests \
	hello \
	cpm22 \
	retro \
	filesystem

CLEAN_DIRS=$(SUBDIRS:%=clean-%)
ALL_DIRS=$(SUBDIRS:%=all-%)

.PHONY: all clean release $(CLEAN_DIRS) $(ALL_DIRS)

all:: $(ALL_DIRS)

clean:: $(CLEAN_DIRS)

world:: clean all

$(ALL_DIRS):
	$(MAKE) -C $(@:all-%=%) all

$(CLEAN_DIRS):
	$(MAKE) -C $(@:clean-%=%) clean


REL_FILES=\
	LICENSE \
	Makefile \
	README-SD.md \
	README.md \
	boot \
	cpm22 \
	doc \
	hello \
	lib \
	retro \
	tests \
	filesystem/Makefile \
	filesystem/README.md \
	filesystem/diskdefs \
    filesystem/retro.img \
	filesystem/sid \
	filesystem/progs/basic/ \
    filesystem/progs/example \
	filesystem/progs/tms9118 \
	filesystem/progs/tty \
	filesystem/progs/README.md

release:
	rm -f 2063-Z80-cpm.tar
	zip -r 2063-Z80-cpm.tar $(REL_FILES)
