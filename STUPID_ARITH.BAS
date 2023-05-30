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

10 DIM A1 (120)
19 REM A1(2) == 12
20 LET A1(2) = 5 + 7
29 REM A1(3) == 108
30 LET A1(1 + 2) = A1(2) * 9
39 REM A1(120) = 12 * 108 = 1296
40 LET A1(A1(2) + A1(3)) = A1(1 * 2) * A1(1 + 1 + 1)
50 PRINT A1(120)
60 END
