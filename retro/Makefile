ASM_FLAGS=-I../lib

all: retro.bin

clean:
	rm -f *.lst *.bin *.hex *.sym cpm22.asm

DATE := $(shell date --rfc-3339=seconds)
GIT_VERSION := $(shell git describe --long --dirty; git show -s --format='%ci')
%.bin: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" | z80asm - -o $@ --list=$(basename $@).lst --label=$(basename $@).sym $(ASM_FLAGS)


# It would be nice if all the labels in CPM22.Z80 could be made file-local
# as well (by prefixing them with a dot.)  But it is not obvious how to do that
# with a simple sed-script.

cpm22.asm: ../cpm22/CPM22.Z80
	expand $^ | sed -e 's/\(^MEM \)/;\1/' -e 's/,M/,(HL)/g' -e 's/^\([[:alpha:]]*:[[:space:]]*JP[[:space:]]*0\)/;\1/' -e 's/^\([[:alpha:]][^: ]*\)\([[:space:]]\)/\1:\2/' > $@

world: clean all


retro.bin: cpm22.asm retro.asm
