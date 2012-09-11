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
