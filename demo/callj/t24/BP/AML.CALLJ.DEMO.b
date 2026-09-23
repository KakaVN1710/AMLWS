    PROGRAM AML.CALLJ.DEMO
*-----------------------------------------------------------------------------
* CALLJ DEMO: T24 -> main.com.aml.AmlClient -> AML web service (mock)
*
*   T24 routine --CALLJ--> AmlClient.callRealTimeScan --HTTP POST--> /AMLWS/api/RealtimeScan
*
* Scenarios:
*   0. CALLJ HelloWorld (training example)
*   1..6 RealTimeScan with different customer profiles
*   7. RealTimeApproval + RealTimeExposure for the hit case
*   8. Common CALLJ errors (wrong class / wrong method / missing '$')
*-----------------------------------------------------------------------------
    CRT STR('=', 78)
    CRT ' CALLJ DEMO: T24 -> AML (AMLWS)               ':TIMEDATE()
    CRT STR('=', 78)

    GOSUB INIT
    GOSUB STEP.HELLO
    GOSUB STEP.SCAN
    GOSUB STEP.APPROVAL
    GOSUB STEP.ERRORS

    CRT STR('=', 78)
    CRT ' END OF DEMO'
    CRT STR('=', 78)
    STOP

*-----------------------------------------------------------------------------
INIT:
* In a real T24 these come from OPERATOR, ID.COMPANY...
    Y.OFFICER = 'SBI602640'
    Y.LOCATION = 'KH0010001'
    Y.SOURCE = 'CBS'
    Y.SERVICE.TYPE = '1'
    Y.REDFLAG = 'Y'
    Y.CLIENT.TYPE = 'I'
    Y.RISK.FACTOR = '2#KH|KH|02|0|0|1|0'
    Y.HIT.ONBOARD = ''
    Y.HIT.REF = ''
    RETURN

*-----------------------------------------------------------------------------
STEP.HELLO:
    CRT
    CRT '--- [0] CALLJ HelloWorld --------------------------------------------------'
    V.REPLY = ''
    CALLJ 'com.temenos.training.HelloWorld', '$greet', 'T24 Developer' SETTING V.REPLY ON ERROR
        CRT 'CALLJ error, SYSTEM(0) = ':SYSTEM(0)
    END
    CRT 'Result from Java: ':V.REPLY
    RETURN

*-----------------------------------------------------------------------------
STEP.SCAN:
    Y.CASE = '1 - Clean customer'
    Y.REF = '1248551' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = 'Heng Soka' ; Y.COUNTRY = 'US'
    Y.YOB = '2000' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = '12356789' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '2 - Watchlist match, high risk'
    Y.REF = '100002' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = 'Nguyen Van A' ; Y.COUNTRY = 'VN'
    Y.YOB = '1985' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = '001085000123' ; Y.PASSPORT = 'C1234567'
    GOSUB RUN.SCAN
    Y.HIT.ONBOARD = Y.ONBOARD.NO
    Y.HIT.REF = Y.REF

    Y.CASE = '3 - Sanctioned country'
    Y.REF = '100003' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = 'Kim Chol' ; Y.COUNTRY = 'KP'
    Y.YOB = '1970' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = 'KP7700112' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '4 - Adverse media'
    Y.REF = '100004' ; Y.CLIENT.EXIST = 'Y' ; Y.NAME = 'Tran Thi B' ; Y.COUNTRY = 'VN'
    Y.YOB = '1990' ; Y.GENDER = 'F' ; Y.CLIENT.NO = '100004' ; Y.CLIENT.ID = '079190000456' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '5 - Name match but whitelisted'
    Y.REF = '100005' ; Y.CLIENT.EXIST = 'Y' ; Y.NAME = 'Nguyen Van A' ; Y.COUNTRY = 'VN'
    Y.YOB = '1985' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '100005' ; Y.CLIENT.ID = 'WL000001' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '6 - Invalid data (no ClientName) -> Java validation error'
    Y.REF = '100006' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = '' ; Y.COUNTRY = 'VN'
    Y.YOB = '1995' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = '001095000789' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN
    RETURN

*-----------------------------------------------------------------------------
RUN.SCAN:
    CRT
    CRT '--- [':Y.CASE:'] ':STR('-', 60 - LEN(Y.CASE))
    Y.PARAM = Y.OFFICER:'@':Y.LOCATION:'@':Y.SOURCE:'@':Y.REF:'@':Y.SERVICE.TYPE
    Y.PARAM = Y.PARAM:'@':Y.REDFLAG:'@':Y.CLIENT.TYPE:'@':Y.CLIENT.EXIST:'@':Y.NAME
    Y.PARAM = Y.PARAM:'@':Y.COUNTRY:'@':Y.YOB:'@':Y.GENDER:'@':Y.CLIENT.NO:'@':Y.CLIENT.ID
    Y.PARAM = Y.PARAM:'@':Y.PASSPORT:'@@@@':Y.RISK.FACTOR

    Y.DECISION = '' ; Y.MESSAGE = '' ; Y.ONBOARD.NO = ''
    CALL AML.SCAN.CUSTOMER(Y.PARAM, Y.DECISION, Y.MESSAGE, Y.ONBOARD.NO)

    CRT 'Customer   : ':Y.NAME:' (':Y.COUNTRY:')'
    BEGIN CASE
        CASE Y.DECISION = 'PASS'
            CRT '=> PASS     : ':Y.MESSAGE:' - CUSTOMER can be committed'
        CASE Y.DECISION = 'OVERRIDE'
            CRT '=> OVERRIDE : ':Y.MESSAGE
        CASE Y.DECISION = 'BLOCK'
            CRT '=> BLOCK    : ':Y.MESSAGE:' - transaction rejected'
        CASE 1
            CRT '=> INTEGRATION ERROR: ':Y.MESSAGE
    END CASE
    RETURN

*-----------------------------------------------------------------------------
STEP.APPROVAL:
    CRT
    CRT '--- [7] Approval status & exposure for OnboardNo ':Y.HIT.ONBOARD:' ':STR('-', 23)
    IF Y.HIT.ONBOARD = '' THEN
        CRT 'No hit case to check'
        RETURN
    END
    CALL AML.CHECK.APPROVAL.SUB(Y.HIT.REF, Y.HIT.ONBOARD)
    CRT 'Tip: approve on the mock:   curl "http://localhost:8089/mock/approve?onboardNo=':Y.HIT.ONBOARD:'&status=A"'
    CRT '     then run again:        AML.CHECK.APPROVAL ':Y.HIT.REF:' ':Y.HIT.ONBOARD
    RETURN

*-----------------------------------------------------------------------------
STEP.ERRORS:
    CRT
    CRT '--- [8] Common CALLJ errors (ON ERROR / SYSTEM(0)) ----------------------'
    Y.RET = ''
    CALLJ 'com.temenos.aml.AmlScanner', '$scanCustomer', 'x' SETTING Y.RET ON ERROR
        CRT '8a. Wrong class name    -> SYSTEM(0) = ':SYSTEM(0):' (Cannot find class)'
    END
    CALLJ 'main.com.aml.AmlClient', '$scanCustomer', 'x' SETTING Y.RET ON ERROR
        CRT '8b. Wrong method name   -> SYSTEM(0) = ':SYSTEM(0):' (Cannot find method)'
    END
    CALLJ 'main.com.aml.AmlClient', 'callRealTimeScan', 'x' SETTING Y.RET ON ERROR
        CRT "8c. Missing '$' static  -> SYSTEM(0) = ":SYSTEM(0):' (Cannot find method)'
    END
    RETURN
END
