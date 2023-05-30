0001 REM Copyright 2023 Lexi Robinson
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

1 PRINT "Hello Loops", I

10 FOR I = 1 TO 10

20 PRINT "loop", I
30 IF I / 2 = INT(I / 2) THEN 100
40 PRINT "odd"
50 GOSUB 1000
60 GOTO 200

100 PRINT "even"
150 GOSUB 2000


200 NEXT I

999 STOP

1000 REM sub1
1002 PRINT "I'm a subroutine", I
1010 RETURN

2000 REM sub2
2001 PRINT "I'm also a subroutine", I
2010 RETURN

9999 END
