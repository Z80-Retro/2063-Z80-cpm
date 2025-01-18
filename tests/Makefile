TOP=..
include $(TOP)/Make.default

all: spi_test.bin sd_test.bin

clean:
	rm -f ldr
	rm -f *.lst *.bin *.hex *.sym

DATE := $(shell date +"%Y-%m-%d %H:%M:%S%z")
GIT_VERSION := $(shell git describe --long --dirty; git show -s --format='%ci')

%.bin: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" | $(CROSS_AS) - -o $@ --list=$(basename $@).lst --label=$(basename $@).sym $(CROSS_AS_FLAGS)


world: clean all

