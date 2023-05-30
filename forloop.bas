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
010 PRINT "BASIC TEST"
020 FOR I = 1 TO 10
030 PRINT I
040 NEXT I
050 PRINT "Slightly more complex"
060 FOR I = 1 TO 10
061 FOR J = 1 TO 10
070 PRINT I,J
071 LET I = I + 1
080 NEXT J
090 NEXT I
100 PRINT "EMBEDDED GOTO"
110 FOR I = 1 TO 10
120 PRINT I
130 IF I = 5 THEN 150
140 NEXT I
150 PRINT "OUT OF LOOP"
9999 END
