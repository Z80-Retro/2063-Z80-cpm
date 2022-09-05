TOP=.
include $(TOP)/Make.rules

TARGETS=\
	retro.pdf

all:: $(TARGETS)

# THis rule prevents a dirty git tag from getting into a rendering
retro.pdf: 2063-Z80-cpm.pdf
	cp $^ $@

clean:: texclean
	rm -f $(TARGETS) 2063-Z80-cpm.pdf *.out
