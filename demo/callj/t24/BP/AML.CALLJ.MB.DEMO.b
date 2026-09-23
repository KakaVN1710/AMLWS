    SUBROUTINE AML.CALLJ.MB.DEMO
*-----------------------------------------------------------------------------
* MAINLINE (no-argument SUBROUTINE): AML real-time scan of Model Bank customers
*   T24 -> CALLJ -> AmlClient (aml-integration-full.jar) -> AML web service
*
* How to run:
*   1) Inside a logged-in T24 session (no OFS_SOURCE needed):
*        PGM.FILE AML.CALLJ.MB.DEMO with TYPE = M, then type AML.CALLJ.MB.DEMO
*        on the T24 command line. Output: <TAFJ_HOME>/log/AML.CALLJ.MB.DEMO.log
*   2) From the TAFJ console:
*        set OFS_SOURCE=<OFS.SOURCE id>
*        tRun AML.CALLJ.MB.DEMO                 scan 5 random customers
*        tRun AML.CALLJ.MB.DEMO 100100 100724   scan the given customers
*
* Compile together with: AML.MB.SCAN.CUSTOMERS, AML.SCAN.CUSTOMER, AML.CALLJ.INVOKE
*-----------------------------------------------------------------------------
    $INSERT I_COMMON
    $INSERT I_EQUATE

* Customer ids from the command line (tRun AML.CALLJ.MB.DEMO <id1> <id2> ...)
    Y.CUS.LIST = ''
    Y.CMD = TRIM(SENTENCE())
    Y.NB.WORDS = DCOUNT(Y.CMD, ' ')
    FOR Y.I = 1 TO Y.NB.WORDS
        Y.WORD = FIELD(Y.CMD, ' ', Y.I)
        IF NUM(Y.WORD) AND Y.WORD NE '' THEN Y.CUS.LIST<-1> = Y.WORD    ;* skip 'tRun' / routine name
    NEXT Y.I

* No ids given -> AML.MB.SCAN.CUSTOMERS takes a sample of 5 customers
    CALL AML.MB.SCAN.CUSTOMERS(Y.CUS.LIST, 'T24 MODEL BANK - AML REAL-TIME SCAN VIA CALLJ')
    RETURN
END
