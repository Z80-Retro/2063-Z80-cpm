
TOP=..
include $(TOP)/Make.default


all: firmware.bin

clean:
	rm -f ldr
	rm -f *.lst *.bin *.hex *.sym

DATE := $(shell date --rfc-3339=seconds)
GIT_VERSION := $(shell git describe --long --dirty; git show -s --format='%ci')
%.bin: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" -e "s/@@BOOT_MSG@@/$(BOOT_MSG)/g" | z80asm - -o $@ --list=$(basename $@).lst --label=$(basename $@).sym $(ASM_FLAGS)


world: clean all

