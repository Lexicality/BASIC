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
