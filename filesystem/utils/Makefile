# This is sort of wonky but the Makefile for xmodem80 is
# not really what I want to use here

SUBDIRS=\
	mbasic \
	archive

SRC=$(wildcard */*.z80)
PROGS=$(SRC:%.z80=%.com)
PROG_DIRS=$(sort $(dir $(SRC)))

all:: $(PROGS)

TOP=../..
include $(TOP)/Make.rules
include $(TOP)/Make.default

.PHONY: all clean world burn blank-all-sd

%.com: %.z80
	z80asm -o $@ $^

clean::
	rm -f $(PROGS)

world::  clean all
