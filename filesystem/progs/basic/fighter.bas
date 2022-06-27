100 REM    A star-fighter/avoidance game 
110 REM
120 REM    Copyright (C) 2021,2022 John Winans
130 REM
140 REM    This library is free software; you can redistribute it and/or
150 REM    modify it under the terms of the GNU Lesser General Public
160 REM    License as published by the Free Software Foundation; either
170 REM    version 2.1 of the License, or (at your option) any later version.
180 REM
190 REM    This library is distributed in the hope that it will be useful,
200 REM    but WITHOUT ANY WARRANTY; without even the implied warranty of
210 REM    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
220 REM    Lesser General Public License for more details.
230 REM
240 REM    You should have received a copy of the GNU Lesser General Public
250 REM    License along with this library; if not, write to the Free Software
260 REM    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
270 REM    USA
280 REM
290 RANDOMIZE 
300 REM shut off the cursor
310 PRINT CHR$(27);"[?25l";
320 REM clear the screen
330 PRINT CHR$(12);
340 LMAX%=2
350 RMAX%=76
360 REM initialize the position queue
370 ROWS%=24
380 DIM PFIFO%(ROWS%)
390 FOR I=0 TO ROWS%-1: PFIFO%(I)=0: NEXT
400 REM goto line 1 in position of the player
410 PLAYER%=39
420 SHIP$="-V-"
430 SCORE%=0
440 IF PFIFO%(1)<>0 AND PLAYER%-1 <= PFIFO%(1) AND PLAYER%+1 >= PFIFO%(1) THEN 650
450 PRINT : REM scroll the display
460 I$=INKEY$
470 IF I$="," AND PLAYER%>LMAX% THEN PLAYER%=PLAYER%-1
480 IF I$="." AND PLAYER%<RMAX% THEN PLAYER%=PLAYER%+1
490 IF I$="q" THEN 690
500 GOSUB 610
510 REM add a new asteroid to the screen
520 SCORE%=SCORE%+1
530 FOR I%=1 TO ROWS%-1: PFIFO%(I%-1) = PFIFO%(I%): NEXT
540 PFIFO%(ROWS%-1) = INT(RND*(RMAX%+1)+1)
550 X$=STR$(PFIFO%(ROWS%-1))
560 PRINT CHR$(&H1B);"[24;";MID$(X$,2,LEN(X$)-1);"H";"*";
570 REM uncomment the following line to slow down the game
580 REM for i%=0 to 1000 : next
590 GOTO 440
600 REM print the player's ship
610 X$=STR$(PLAYER%-1)
620 PRINT CHR$(&H1B);"[1;";MID$(X$,2,LEN(X$)-1);"H";SHIP$
630 RETURN
640 REM turn cursor back on
650 PRINT CHR$(&H1B);"[4;1H";"BOOM!"
660 PRINT "Your score is: ";SCORE%
670 PRINT CHR$(&H1B);"[?25h";
680 END
690 PRINT CHR$(&H1B);"[4;1H";"quitting..."
700 GOTO 660
