//****************************************************************************
//
//    Copyright (C) 2023 John Winans
//
//    This library is free software; you can redistribute it and/or
//    modify it under the terms of the GNU Lesser General Public
//    License as published by the Free Software Foundation; either
//    version 2.1 of the License, or (at your option) any later version.
//
//    This library is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//    Lesser General Public License for more details.
//
//    You should have received a copy of the GNU Lesser General Public
//    License along with this library; if not, write to the Free Software
//    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
//    USA
//
//
//****************************************************************************

#include "serial.h"
#include "hexdump.h"

#include <fcntl.h>
#include <unistd.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

#define SOM	('s')
#define EOM	('e')

#pragma pack(1)
struct get_block {
	uint8_t		som;
	uint8_t		type;	// 0x07
	uint8_t		index;
	uint32_t	block;
	uint16_t	len;
	uint8_t		eom;
};
#pragma pack()

#pragma pack(1)
struct data_buffer {
	uint8_t		som;
	uint8_t		type;	// 0x84
	uint16_t	len;
	uint8_t		data[128];	
	uint8_t		eom;
};
#pragma pack()



/**
*****************************************************************************/
void send_data_buffer(int port)
{
	struct data_buffer msg = {
		.som	= SOM,
		.type	= 0x84,
		.len	= 128,
		.data	= { 0,1,2,3,4,5,6,7,8,9,10,0 },	// some data that does not require escaping
		.eom	= EOM
	};

	static int ctr = 0;

	msg.data[0] = ctr++;

	printf("TX:\n");
	hexdump((char*)&msg, sizeof(msg));
	write(port, &msg, sizeof(msg));
}

/**
* Generate NHACP test messages
*****************************************************************************/
static void nhacp_msg(int port)
{
	//char	msg1[] = "sabcdezzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzze";
	//char	msg2[] = "s1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1be";

	printf("NHACP message beacon\n");

	char	buf[256];

	for (;;)
	{
		fd_set  fds;
		FD_ZERO(&fds);
		FD_SET(port, &fds);
		select(port+1, &fds, NULL, NULL, NULL);

		ssize_t len = read(port, buf, sizeof(buf));
		printf("RX:\n");
		hexdump(buf, len);
		if (len)
		{
			sleep(1);	// a pretty bad way to buffer up a response message ;-)
			send_data_buffer(port);
			//write(port, &msg1, sizeof(msg1)-1);
		}
	}
}

/**
*****************************************************************************/
static void usage()
{
	fprintf(stderr, "Options:\n"
		"    [-t tty]    Specify the TTY to use.\n");
	exit(1);
}

/**
*****************************************************************************/
int main(int argc, char **argv)
{
    int port;
    //const char *tty = "/dev/ttyUSB0";		// default tty name
    const char *tty = "/dev/ttyUSB1";		// default tty name
	int ch;
	int rts = 0;
	int terminal = 0;

	speed_t speed = B115200;

    extern char *optarg;

	while((ch = getopt(argc, argv, "4t:x")) != -1)
	{
		switch (ch)
		{
		case 't':		// tty port
			tty = optarg;
			break;

		case '4':	// RS485 set RTS to turn off transmitter
			rts = 1;
			break;
			
		case 'x':	// open, reset, isp, etc and then exit right away
			terminal = 1;
			break;

		default:
			usage();
		}
	}

	printf("opening %s\n", tty);

    /* Open the tty */
    if ((port = open(tty, O_RDWR | O_NOCTTY | O_NONBLOCK, 0)) < 0)
    {
        printf("Can not open '%s'\n", tty);
        exit(-1);
    }
    initPort(port, speed);

	if (rts)
		setControlLines(port, 1, 0);

	if (terminal)
		doStream(port);		// uber-dumb terminal
	else
		nhacp_msg(port);

	close(port);
	return(0);
}
