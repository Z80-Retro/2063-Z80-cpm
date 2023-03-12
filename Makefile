SUBDIRS=\
	boot \
	tests \
	hello \
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
	filesystem/assemblers

release:
	rm -f 2063-Z80-cpm.zip
	zip -r 2063-Z80-cpm.zip $(REL_FILES)
