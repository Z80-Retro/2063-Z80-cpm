SUBDIRS=\
	boot \
	tests \
	hello \
	cpm22


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

