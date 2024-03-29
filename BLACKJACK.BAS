0001 REM Copyright 2012 Lexi Robinson
0001 REM
0001 REM Licensed under the Apache License, Version 2.0 (the "License");
0001 REM you may not use this file except in compliance with the License.
0001 REM You may obtain a copy of the License at
0001 REM
0001 REM     http://www.apache.org/licenses/LICENSE-2.0
0001 REM
0001 REM Unless required by applicable law or agreed to in writing, software
0001 REM distributed under the License is distributed on an "AS IS" BASIS,
0001 REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
0001 REM See the License for the specific language governing permissions and
0001 REM limitations under the License.

010 PRINT "Lexical Blackjack!"
020 REM PRESTART SETUP
021 OPTION BASE 1
022 REM RANDOMIZE
029 REM C = THE DECK OF 52 CARDS TO ENSURE EACH CARD IS ONLY EVER DEALT ONCE
030 DIM C(52)
039 REM H = THE AMOUNT OF EACH KIND OF CARD THE PLAYER HAS
040 DIM H(13)
049 REM FNR(N) = RANDOM INT BETWEEN 1 AND N
050 DEF FNR(N) = INT(RND * N) + 1

140 REM SETUP
149 REM PLAYER HAND VALUES. 1 = PLAYER, 2 = AI
150 LET H1 = 0
151 LET H2 = 0
159 REM ACE COUNTS
160 LET A1 = 0
161 LET A2 = 0
170 REM CARD DRAWS
171 FOR I = 1 TO 52
172 LET C(I) = 0
173 NEXT I
180 REM HAND CONTENTS
181 FOR I = 1 TO 12
182 LET H(I) = 0
183 NEXT I

290 REM SET UP INITIAL HAND
291 GOSUB 1150
292 GOSUB 1100
293 GOSUB 1100
299 GOTO 370

300 REM GAME LOOP
310 GOSUB 1200
320 PRINT "DRAW or STAY?"
330 INPUT I$
340 IF I$ <> "STAY" THEN 350
341 GOTO 400
350 IF I$ <> "DRAW" THEN 320
360 GOSUB 1100
370 REM CHECK FOR WIN/LOSS
371 IF H1 <= 21 THEN 380
372 GOTO 910
380 GOSUB 1300
381 IF R <> 21 THEN 300
389 REM TURN OVER THE DEALER'S CARD
390 GOSUB 1150
393 GOSUB 1305
394 IF R <> 21 THEN 900
395 PRINT "The dealer matched your 21"
396 GOTO 910

400 REM AI SECTION
410 GOSUB 1150
420 GOSUB 1305
430 IF R  = 21 THEN 910
431 IF R  > 21 THEN 900
440 IF H2 < 17 THEN 400
450 LET R0 = R
460 GOSUB 1300
461 REM DEBUGGER
470 IF R > R0 THEN 900
480 GOTO 910

900 REM YOU WON
901 PRINT "Congratulations, you won!"
902 GOTO 920
910 REM YOU LOST
911 PRINT "Looks like you lost."
919 REM INFO
920 GOSUB 1300
921 PRINT "Your final score was: "; R
930 GOSUB 1305
931 PRINT "The dealer scored: "; R
139 REM REPLAY
940 PRINT "Do you want to play again? Y/N"
950 INPUT I$
960 IF I$ = "Y" THEN 140

999 STOP

1000 REM DRAW_HAND
1010 LET R = FNR(52)
1011 IF C(R) <> 0 THEN 1010
1020 LET C(R) = 1
1030 IF R <= 13 THEN 1040
1031 LET R = R - 13
1032 GOTO 1030
1040 LET R1 = R
1041 IF R <= 10 THEN 1050
1042 REM GET THE ACTUAL VALUE
1043 LET R = 10
1050 REM DONE
1099 RETURN

1100 REM DRAW_PLAYER
1110 GOSUB 1000
1120 LET H1 = H1 + R
1121 LET H(R1) = H(R1) + 1
1130 IF R1 <> 1 THEN 1140
1131 LET A1 = A1 + 1
1140 REM GET THE CARD NAME
1141 LET P1 = R1
1142 GOSUB 1400
1143 PRINT "You drew a "; R$
1149 RETURN

1150 REM DRAW_DEALER
1160 GOSUB 1000
1170 LET H2 = H2 + R
1180 IF R1 <> 1 THEN 1190
1181 LET A2 = A2 + 1
1190 REM GET THE CARD NAME
1191 LET P1 = R1
1192 GOSUB 1400
1193 PRINT "The dealer drew a "; R$
1199 RETURN

1200 REM ENUMERATE_HAND
1201 PRINT "You have in your hand:"
1209 REM NUMBER CARDS
1210 FOR I = 2 TO 10
1211 GOSUB 1270
1212 NEXT I
1219 REM PICTURE CARDS
1220 IF H(1) = 0 THEN 1230
1221 PRINT H(1); " Aces"
1230 IF H(11) = 0 THEN 1240
1231 PRINT H(11); " Jacks"
1240 IF H(12) = 0 THEN 1250
1241 PRINT H(12); " Queens"
1250 IF H(13) = 0 THEN 1260
1251 PRINT H(13); " Kings"
1260 RETURN
1270 REM FFS
1271 IF H(I) = 0 THEN 1290
1280 PRINT H(I); " "; I; "s"
1290 RETURN


1300 REM WORK_OUT_WIN
1301 REM PLAYER ENTRY
1302 LET P1 = H1
1303 LET P2 = A1
1304 GOTO 1310
1305 REM AI ENTRY
1306 LET P1 = H2
1307 LET P2 = A2
1310 REM MAIN FUNCTION
1311 LET R = P1
1320 IF R >= 21 THEN 1399
1330 IF P2 = 0  THEN 1399
1340 LET P2 = P2 - 1
1350 LET R = R + 10
1360 IF R <= 21 THEN 1320
1369 REM UNDO THE LAST ADD
1370 LET R = R - 10
1399 RETURN

1400 REM WHAT CARD
1410 IF P1 <> 1 THEN 1420
1411 LET R$ = "Ace"
1414 GOTO 1499
1420 IF P1 > 10 THEN 1430
1421 LET R$ = P1
1422 GOTO 1499
1430 IF P1 <> 11 THEN 1440
1431 LET R$ = "Jack"
1432 GOTO 1499
1440 IF P1 <> 12 THEN 1450
1441 LET R$ = "Queen"
1442 GOTO 1499
1450 LET R$ = "King"
1499 RETURN

9999 END
