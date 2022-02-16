ASM_FLAGS=-I../lib


all: firmware.bin

clean:
	rm -f ldr
	rm -f *.lst *.bin *.hex *.sym

DATE := $(shell date --rfc-3339=seconds)
GIT_VERSION := $(shell git describe --long --dirty; git show -s --format='%ci')
%.bin: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" | z80asm - -o $@ --list=$(basename $@).lst --label=$(basename $@).sym $(ASM_FLAGS)


world: clean all

