    SUBROUTINE AML.SCAN.CUSTOMER(Y.PARAM, Y.DECISION, Y.MESSAGE, Y.ONBOARD.NO)
*-----------------------------------------------------------------------------
* Calls AML RealTimeScan through CALLJ and returns the T24 decision
*
* IN  : Y.PARAM       19 fields separated by '@' (see RealTimeScanRequest.fromDelimitedString)
*         1 OfficerId      2 Location     3 Source        4 ReferenceNo
*         5 ServiceType    6 RedFlagType  7 ClientType    8 ClientExist
*         9 ClientName    10 ClientCountry 11 ClientYOB   12 ClientGender
*        13 ClientNo      14 ClientID    15 PassportNo    16 PassportNoSec
*        17 PassportExpDate 18 PassportExpDateSec          19 RiskFactor
* OUT : Y.DECISION    PASS | OVERRIDE | BLOCK | ERROR
*       Y.MESSAGE     override / error message
*       Y.ONBOARD.NO  AML case number (when there is a hit)
*-----------------------------------------------------------------------------
    Y.DECISION = ''
    Y.MESSAGE = ''
    Y.ONBOARD.NO = ''
    Y.RESULT = ''
    Y.ERROR = ''

    CALL AML.CALLJ.INVOKE('callRealTimeScan', Y.PARAM, Y.RESULT, Y.ERROR)
    IF Y.ERROR NE '' THEN
        Y.DECISION = 'ERROR'
        Y.MESSAGE = Y.ERROR
        RETURN
    END

    GOSUB PARSE.RESULT
    GOSUB DECIDE
    RETURN

*-----------------------------------------------------------------------------
PARSE.RESULT:
* RealTimeScanResponse.toDelimitedString() - fields separated by '#'
    Y.MATCH.STATUS = FIELD(Y.RESULT, '#', 1)
    Y.WHITELIST.STATUS = FIELD(Y.RESULT, '#', 2)
    Y.ONBOARD.NO = FIELD(Y.RESULT, '#', 3)
    Y.MATCH.URL = FIELD(Y.RESULT, '#', 4)
    Y.RISK.STATUS = FIELD(Y.RESULT, '#', 5)
    Y.PASSPORT.STATUS = FIELD(Y.RESULT, '#', 6)
    Y.SANCTION.STATUS = FIELD(Y.RESULT, '#', 7)
    Y.EDD.STATUS = FIELD(Y.RESULT, '#', 8)
    Y.EDD.URL = FIELD(Y.RESULT, '#', 9)
    Y.ADV.MEDIA.STATUS = FIELD(Y.RESULT, '#', 10)
    Y.ADV.MEDIA.URL = FIELD(Y.RESULT, '#', 11)
    IF Y.ONBOARD.NO = '0' THEN Y.ONBOARD.NO = ''
    RETURN

*-----------------------------------------------------------------------------
DECIDE:
    BEGIN CASE
        CASE Y.WHITELIST.STATUS = 'T'
            Y.DECISION = 'PASS'
            Y.MESSAGE = 'Customer is in AML whitelist'
        CASE Y.SANCTION.STATUS = 'T'
            Y.DECISION = 'BLOCK'
            Y.MESSAGE = 'Customer country is under sanction - OnboardNo ':Y.ONBOARD.NO
        CASE Y.MATCH.STATUS = 'T' AND Y.RISK.STATUS = 'H'
            Y.DECISION = 'OVERRIDE'
            Y.MESSAGE = 'Customer is high risk by AML (watchlist match) - OnboardNo ':Y.ONBOARD.NO
        CASE Y.EDD.STATUS = 'T' OR Y.ADV.MEDIA.STATUS = 'T'
            Y.DECISION = 'OVERRIDE'
            Y.MESSAGE = 'AML requires EDD (adverse media) - OnboardNo ':Y.ONBOARD.NO
        CASE 1
            Y.DECISION = 'PASS'
            Y.MESSAGE = 'No AML hit'
    END CASE
    RETURN
END
