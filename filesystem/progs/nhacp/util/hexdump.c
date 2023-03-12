//****************************************************************************
//
//    Copyright (C) 2020,2023  John Winans
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
//    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301
//    USA
//
//****************************************************************************

#include "hexdump.h"

#include <stdio.h>
#include <ctype.h>

void hexdump(char *buf, uint32_t length)
{
    int             ch;
    int             i = 0;
    uint32_t        j;
    unsigned char   ascii[20];  /* to hold printable portion of string */

    if (length==0)
        return;

    for(j=0; j<length; ++j)
    {
        ch = buf[j];
        if ((j % 16) == 0)
        {
			if (j)
			{
            	ascii[i] = '\0';
            	printf(" *%s*\n", ascii);
			}
            printf(" %4.4x:", j);
            i = 0;
        }
        printf("%s%2.2x", (j%8==0&&j%16!=0)?"  ":" ", ch & 0xff);

        ascii[i] = ch;
        if ((ascii[i] >= 0x80)||(!isprint(ascii[i])))
            ascii[i] = '.';
        ++i;
    }
    if (j%16 && j%16<9)
        printf(" ");
    while (j%16)
    {
        printf("   ");
        ++j;
    }
    ascii[i] = '\0';
    printf(" *%s*\n", ascii);
}
