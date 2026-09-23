    PROGRAM AML.CALLJ.DEMO
*-----------------------------------------------------------------------------
* DEMO CALLJ tu T24 -> main.com.aml.AmlClient -> AML Web Service (mock)
*
*   T24 routine --CALLJ--> AmlClient.callRealTimeScan --HTTP POST--> /AMLWS/api/RealtimeScan
*
* Kich ban:
*   0. CALLJ HelloWorld (vi du trong tai lieu)
*   1..6 RealTimeScan voi cac ho so khach hang khac nhau
*   7. RealTimeApproval + RealTimeExposure cho ho so bi hit
*   8. Cac loi CALLJ thuong gap (sai class / sai method / quen '$')
*-----------------------------------------------------------------------------
    CRT STR('=', 78)
    CRT ' DEMO CALLJ T24 -> AML (AMLWS)                ':TIMEDATE()
    CRT STR('=', 78)

    GOSUB INIT
    GOSUB STEP.HELLO
    GOSUB STEP.SCAN
    GOSUB STEP.APPROVAL
    GOSUB STEP.ERRORS

    CRT STR('=', 78)
    CRT ' KET THUC DEMO'
    CRT STR('=', 78)
    STOP

*-----------------------------------------------------------------------------
INIT:
* Cac gia tri thuong lay tu OPERATOR, ID.COMPANY... trong T24 that
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
    Y.CASE = '1 - Khach hang sach'
    Y.REF = '1248551' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = 'Heng Soka' ; Y.COUNTRY = 'US'
    Y.YOB = '2000' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = '12356789' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '2 - Trung watchlist, rui ro cao'
    Y.REF = '100002' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = 'Nguyen Van A' ; Y.COUNTRY = 'VN'
    Y.YOB = '1985' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = '001085000123' ; Y.PASSPORT = 'C1234567'
    GOSUB RUN.SCAN
    Y.HIT.ONBOARD = Y.ONBOARD.NO
    Y.HIT.REF = Y.REF

    Y.CASE = '3 - Quoc gia bi cam van'
    Y.REF = '100003' ; Y.CLIENT.EXIST = 'N' ; Y.NAME = 'Kim Chol' ; Y.COUNTRY = 'KP'
    Y.YOB = '1970' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '' ; Y.CLIENT.ID = 'KP7700112' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '4 - Tin tuc tieu cuc (adverse media)'
    Y.REF = '100004' ; Y.CLIENT.EXIST = 'Y' ; Y.NAME = 'Tran Thi B' ; Y.COUNTRY = 'VN'
    Y.YOB = '1990' ; Y.GENDER = 'F' ; Y.CLIENT.NO = '100004' ; Y.CLIENT.ID = '079190000456' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '5 - Trung ten nhung nam trong whitelist'
    Y.REF = '100005' ; Y.CLIENT.EXIST = 'Y' ; Y.NAME = 'Nguyen Van A' ; Y.COUNTRY = 'VN'
    Y.YOB = '1985' ; Y.GENDER = 'M' ; Y.CLIENT.NO = '100005' ; Y.CLIENT.ID = 'WL000001' ; Y.PASSPORT = ''
    GOSUB RUN.SCAN

    Y.CASE = '6 - Du lieu sai (thieu ClientName) -> Java validate loi'
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

    CRT 'Khach hang : ':Y.NAME:' (':Y.COUNTRY:')'
    BEGIN CASE
        CASE Y.DECISION = 'PASS'
            CRT '=> PASS     : ':Y.MESSAGE:' - cho phep commit CUSTOMER'
        CASE Y.DECISION = 'OVERRIDE'
            CRT '=> OVERRIDE : ':Y.MESSAGE
        CASE Y.DECISION = 'BLOCK'
            CRT '=> ERROR    : ':Y.MESSAGE:' - chan giao dich'
        CASE 1
            CRT '=> LOI TICH HOP: ':Y.MESSAGE
    END CASE
    RETURN

*-----------------------------------------------------------------------------
STEP.APPROVAL:
    CRT
    CRT '--- [7] Kiem tra phe duyet & exposure cho OnboardNo ':Y.HIT.ONBOARD:' ':STR('-', 20)
    IF Y.HIT.ONBOARD = '' THEN
        CRT 'Khong co ho so hit de kiem tra'
        RETURN
    END
    CALL AML.CHECK.APPROVAL.SUB(Y.HIT.REF, Y.HIT.ONBOARD)
    CRT 'Goi y: phe duyet tren mock:  curl "http://localhost:8089/mock/approve?onboardNo=':Y.HIT.ONBOARD:'&status=A"'
    CRT '       roi chay lai:          AML.CHECK.APPROVAL ':Y.HIT.REF:' ':Y.HIT.ONBOARD
    RETURN

*-----------------------------------------------------------------------------
STEP.ERRORS:
    CRT
    CRT '--- [8] Loi CALLJ thuong gap (ON ERROR / SYSTEM(0)) ---------------------'
    Y.RET = ''
    CALLJ 'com.temenos.aml.AmlScanner', '$scanCustomer', 'x' SETTING Y.RET ON ERROR
        CRT '8a. Sai ten class     -> SYSTEM(0) = ':SYSTEM(0):' (Cannot find class)'
    END
    CALLJ 'main.com.aml.AmlClient', '$scanCustomer', 'x' SETTING Y.RET ON ERROR
        CRT '8b. Sai ten method    -> SYSTEM(0) = ':SYSTEM(0):' (Cannot find method)'
    END
    CALLJ 'main.com.aml.AmlClient', 'callRealTimeScan', 'x' SETTING Y.RET ON ERROR
        CRT "8c. Quen '$' (static)  -> SYSTEM(0) = ":SYSTEM(0):' (Cannot find method)'
    END
    RETURN
END
