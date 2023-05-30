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

10 LET A = 3 + 4 * 2 / ( 1 - 5 ) ^ 2 ^ 3
20 REM Fun fact: ECMA-55 has different ideas about associativity to everyone else. ^ is therefore left assoc
30 PRINT A
40 END
