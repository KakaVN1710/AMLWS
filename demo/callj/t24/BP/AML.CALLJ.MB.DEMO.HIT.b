    SUBROUTINE AML.CALLJ.MB.DEMO.HIT
*-----------------------------------------------------------------------------
* MAINLINE (no-argument SUBROUTINE): AML hit scenario on a fixed customer
*
*   CUSTOMER 10000083 - Solomon David (US, 1971)
*   The mock AML server has this customer on its watchlist, so the scan returns
*   MatchStatus=T / RiskStatus=H -> OVERRIDE "Customer is high risk by AML",
*   followed by the approval status (PENDING until Compliance approves) and exposure.
*
* How to run:
*   - T24 command line: PGM.FILE AML.CALLJ.MB.DEMO.HIT with TYPE = M, then type
*     AML.CALLJ.MB.DEMO.HIT. Output: <TAFJ_HOME>/log/AML.CALLJ.MB.DEMO.log
*   - TAFJ console: set OFS_SOURCE=<OFS.SOURCE id> & tRun AML.CALLJ.MB.DEMO.HIT
*
* Compile together with: AML.MB.SCAN.CUSTOMERS, AML.SCAN.CUSTOMER, AML.CALLJ.INVOKE
*-----------------------------------------------------------------------------
    $INSERT I_COMMON
    $INSERT I_EQUATE

    Y.CUS.LIST = '10000083'
    CALL AML.MB.SCAN.CUSTOMERS(Y.CUS.LIST, 'T24 MODEL BANK - AML HIT SCENARIO (CUSTOMER 10000083)')
    RETURN
END
