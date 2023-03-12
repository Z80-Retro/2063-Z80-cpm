CC=gcc
CFLAGS+=-Wall -Werror

all: nhacpd 

clean:
	rm -f *.o nhacpd 

world: clean all


nhacpd: nhacpd.o serial.o hexdump.o
	$(LINK.c) -o $@ $^
