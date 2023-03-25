ASM_FLAGS=-I../lib

all: retro.bin

clean:
	rm -f *.lst *.bin *.hex *.sym 

DATE := $(shell date --rfc-3339=seconds)
#DATE := "xxx"
GIT_VERSION := $(shell git describe --long --dirty; git show -s --format='%ci')
%.bin: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" | z80asm - -o $@ --list=$(basename $@).lst --label=$(basename $@).sym $(ASM_FLAGS)

world: clean all

retro.bin: ../cpm-2.2/src/cpm22.asm retro.asm 
retro.bin: disk_callgate.asm disk_config.asm 
retro.bin: disk_dmcache.asm disk_nhacp.asm disk_nocache.asm disk_stub.asm
