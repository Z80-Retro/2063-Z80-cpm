//****************************************************************************
//
//    Copyright (C) 2001-2023 John Winans
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

/* For linux... see termios(4) */
#include <termios.h>

#include <unistd.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <sys/ioctl.h>
#include <sys/file.h>
//#include <sgtty.h>
#include <sys/time.h>
#include <string.h>

//#define DEBUG_IO

/**
*****************************************************************************/
void setControlLines(int port, int dtr, int rts)
{
    int status;

    if(ioctl(port, TIOCMGET, &status) != 0)
	{
		perror("Ioctl get failed ");
		exit(1);
	}

    if(dtr)
		status |=  TIOCM_DTR;
    else
		status &= ~TIOCM_DTR;

    if(rts)
		status |=  TIOCM_RTS;
    else
		status &= ~TIOCM_RTS;

    if(ioctl(port, TIOCMSET, &status) != 0)
	{
		perror("Ioctl set failed ");
		exit(1);
	}
}

/**
*****************************************************************************/
void initPort(int p, speed_t speed)
{
    struct termios tio;
    memset(&tio, 0, sizeof(tio));

    tcflush(p, TCIOFLUSH);

    tio.c_iflag = IGNBRK|IGNPAR;
    tio.c_oflag = 0;
   	tio.c_cflag = CS8|CREAD|CLOCAL|HUPCL;
    tio.c_lflag = 0;
    cfsetispeed(&tio, speed);
    cfsetospeed(&tio, speed);
    tcsetattr(p, TCSANOW, &tio);
}

/**
* Wait for a character to arrive, read it and return its value.
*****************************************************************************/
int readChar(int port)
{
	int i;
	char ch;

	fd_set  fds;
	FD_ZERO(&fds);
	FD_SET(port, &fds);
	select(port+1, &fds, NULL, NULL, NULL);
	ssize_t rc = read(port, &ch, 1);
	if (rc == 0 || rc == -1)
	{
		fprintf(stderr, "EOF\r\n");
		return(-1);
	}

	i = ch & 0x0ff;
#ifdef DEBUG_IO
	printf("Read %2.2X '%c' status=%zd\n", i, ch, rc);
#endif
	return(i);
}

/**
* Send the given character and read the echo response.
*****************************************************************************/
void sendChar(int port, char ch)
{

	//usleep(100);
	write(port, &ch, 1);
#ifdef DEBUG_IO
	int i = ch & 0x0ff;
	printf("Write %2.2X '%c'\n", i, ch);
#endif
}

/**
* spew raw data from tty to stdout
*****************************************************************************/
void doStream(int port)
{
	printf("Terminal started. ESC to terminate.\n");
	fflush(stdout);

#if 0
	while(1)
	{
		putchar(readChar(port));
		fflush(stdout);
	}
#else
	// Change the tty to raw mode
    struct termios tsave;
    struct termios tio;
    memset(&tio, 0, sizeof(tsave));
    memset(&tio, 0, sizeof(tio));
	tcgetattr(0, &tsave);

	tcgetattr(0, &tio);
	cfmakeraw(&tio);
    tcsetattr(0, TCSANOW, &tio);

	while(1)
	{
		fd_set rfds;
		int retval;

		// Watch stdin and the tty for input

		FD_ZERO(&rfds);
		FD_SET(0, &rfds);
		FD_SET(port, &rfds);

		retval = select(port+1, &rfds, NULL, NULL, NULL);

		if (retval == -1)
		{
			perror("select()");
		}
		else if (retval)
		{
			if (FD_ISSET(0, &rfds))
			{
				//int ch = getchar();		// STUPID!!!!
                char ch;
                if (read(0, &ch, 1) <= 0)
				{
					fprintf(stderr, "\r\nEOF\r\n");
					break;
				}

				if (ch == 0x1B)	// ESC
				{
					printf("ESC key pressed, terminating\r\n");
					break;
				}

				sendChar(port, ch);
				//putchar(ch);
				//fflush(stdout);
			}
			if (FD_ISSET(port, &rfds))
			{
				int ch = readChar(port);
				if (ch < 0)
					break;
				putchar(ch);
				fflush(stdout);
			}
		}
	}

	// tty back to cooked mode
    tcsetattr(0, TCSANOW, &tsave);
#endif
}
