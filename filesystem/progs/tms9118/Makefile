PROGS=\
	green.com \
	white.com \
	dram.com \
	mode1.com \
	mode2.com \
	mode1i2.com \
	mode1a.com \
	m1t1.com \
	m1t2.com \
	sprites.com \
	breakout.com


all: $(PROGS)

clean:
	rm -f *.lst *.bin *.com *.hex *.sym

DATE := $(shell date --rfc-3339=seconds)
GIT_VERSION := $(shell git describe --long --dirty; git show -s --format='%ci')
%.com: %.asm
	cat $< | sed -e "s/@@DATE@@/$(DATE)/g" -e "s/@@GIT_VERSION@@/$(GIT_VERSION)/g" | z80asm - -o $@ --list=$(basename $@).lst --label=$(basename $@).sym $(ASM_FLAGS)

world: clean all

