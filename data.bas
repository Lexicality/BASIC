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

1 DATA 5
2 DATA 5, 6
3 DATA "hello, computer"
4 DATA e
5 DATA ee
10 DATA hello computer
11 DATA    hello    , "hello"
20 DATA -.2E-1, +1, all of these are actually valid unquoted strings
21 DATA +1.E+1, 1E1, 1.E1
22 DATA "this isn't a valid number:", 1e1
30 DATA beans on toast, 5e4, 5this is actually a string.2, "huh"
9999 END
