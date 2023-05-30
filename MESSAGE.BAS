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

10 PRINT "Please input the message you want repeated followed by the number of repitions."
20 INPUT M$, R
30 IF R < 1 THEN 70
40 PRINT M$
50 LET R = R - 1
60 GOTO 30
70 PRINT "Would you like to repeat another message? [Y/N]"
80 INPUT C$
90 IF C$ = "Y" THEN 10
99 END
