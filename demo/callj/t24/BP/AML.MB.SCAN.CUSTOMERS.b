    SUBROUTINE AML.MB.SCAN.CUSTOMERS(Y.CUS.LIST, Y.TITLE)
*-----------------------------------------------------------------------------
* Shared engine of the Model Bank demos (AML.CALLJ.MB.DEMO, AML.CALLJ.MB.DEMO.HIT)
*
* IN : Y.CUS.LIST  CUSTOMER ids separated by FM (empty -> sample of 5 customers)
*      Y.TITLE     banner title
*
* For each customer: read the real CUSTOMER record -> build the '@' delimited
*   request -> CALL AML.SCAN.CUSTOMER -> CALLJ main.com.aml.AmlClient.$callRealTimeScan
*   -> PASS / OVERRIDE / BLOCK / ERROR.
* Every hit is then checked for approval status and exposure.
*
* Output goes to the console (CRT) and to <TAFJ_HOME>/log/AML.CALLJ.MB.DEMO.log
* (CRT is not visible when the routine is started from the Browser).
*-----------------------------------------------------------------------------
    $INSERT I_COMMON
    $INSERT I_EQUATE
    $INSERT I_F.CUSTOMER

    GOSUB INITIALISE.SESSION
    IF Y.STOP THEN RETURN
    GOSUB OPEN.LOG
    GOSUB OPEN.FILES
    IF Y.CUS.LIST = '' THEN GOSUB SELECT.SAMPLE

    Y.LINE = STR('=', 78) ; GOSUB SHOW
    Y.LINE = ' ':Y.TITLE:'   ':TIMEDATE() ; GOSUB SHOW
    Y.LINE = ' Company: ':ID.COMPANY:'   Operator: ':OPERATOR:'   Customers: ':DCOUNT(Y.CUS.LIST, FM) ; GOSUB SHOW
    Y.LINE = STR('=', 78) ; GOSUB SHOW

    Y.CNT.PASS = 0 ; Y.CNT.OVR = 0 ; Y.CNT.BLOCK = 0 ; Y.CNT.ERR = 0
    Y.HIT.LIST = ''
    Y.WORK.LIST = Y.CUS.LIST
    LOOP
        REMOVE Y.CUS.ID FROM Y.WORK.LIST SETTING Y.POS
    WHILE Y.CUS.ID : Y.POS
        GOSUB PROCESS.CUSTOMER
    REPEAT

    GOSUB CHECK.HITS

    Y.LINE = '' ; GOSUB SHOW
    Y.LINE = STR('=', 78) ; GOSUB SHOW
    Y.LINE = ' SUMMARY: PASS=':Y.CNT.PASS:'  OVERRIDE=':Y.CNT.OVR:'  BLOCK=':Y.CNT.BLOCK:'  ERROR=':Y.CNT.ERR ; GOSUB SHOW
    Y.LINE = STR('=', 78) ; GOSUB SHOW

    GOSUB CLOSE.LOG
    RETURN

*-----------------------------------------------------------------------------
INITIALISE.SESSION:
* Started inside a T24 session (Browser / command line) -> commons are loaded.
* Started with tRun -> commons are empty, initialise through JF.INITIALISE.CONNECTION
*   (needs environment variable OFS_SOURCE = id of an OFS.SOURCE record, see LIST F.OFS.SOURCE)
    Y.STOP = 0
    IF ID.COMPANY NE '' THEN RETURN

    Y.OFS.SOURCE = ''
    IF NOT(GETENV('OFS_SOURCE', Y.OFS.SOURCE)) THEN Y.OFS.SOURCE = ''
    IF Y.OFS.SOURCE = '' THEN
        CRT 'Running outside a T24 session: environment variable OFS_SOURCE is required.'
        CRT 'Example:  set OFS_SOURCE=OFSONLINE   then run tRun again'
        CRT 'Or start the routine from the T24 command line (PGM.FILE TYPE = M).'
        Y.STOP = 1
        RETURN
    END
    CRT 'OFS_SOURCE = ':Y.OFS.SOURCE
    CALL JF.INITIALISE.CONNECTION
    IF ID.COMPANY = '' THEN CALL LOAD.COMPANY('GB0010001')      ;* Model Bank default company
    IF OPERATOR = '' THEN OPERATOR = 'INPUTTER'
    RETURN

*-----------------------------------------------------------------------------
OPEN.LOG:
    Y.LOG.PATH = ''
    Y.TAFJ.HOME = ''
    IF NOT(GETENV('TAFJ_HOME', Y.TAFJ.HOME)) THEN Y.TAFJ.HOME = ''
    IF Y.TAFJ.HOME = '' THEN RETURN
    Y.LOG.PATH = Y.TAFJ.HOME:'/log/AML.CALLJ.MB.DEMO.log'
    OPENSEQ Y.LOG.PATH TO F.LOG THEN
        WEOFSEQ F.LOG                                           ;* overwrite previous run
    END ELSE
        CREATE F.LOG ELSE Y.LOG.PATH = ''
    END
    RETURN

*-----------------------------------------------------------------------------
SHOW:
    CRT Y.LINE
    IF Y.LOG.PATH NE '' THEN
        WRITESEQ Y.LINE TO F.LOG ELSE Y.LOG.PATH = ''             ;* write error -> console only
    END
    RETURN

*-----------------------------------------------------------------------------
CLOSE.LOG:
    IF Y.LOG.PATH = '' THEN RETURN
    CLOSESEQ F.LOG
    CRT 'Log file: ':Y.LOG.PATH
    RETURN

*-----------------------------------------------------------------------------
OPEN.FILES:
    FN.CUSTOMER = 'F.CUSTOMER'
    F.CUSTOMER = ''
    CALL OPF(FN.CUSTOMER, F.CUSTOMER)
    RETURN

*-----------------------------------------------------------------------------
SELECT.SAMPLE:
    SEL.CMD = 'SELECT ':FN.CUSTOMER:' SAMPLE 5'
    SEL.LIST = '' ; NO.OF.REC = 0 ; SEL.ERR = ''
    CALL EB.READLIST(SEL.CMD, SEL.LIST, '', NO.OF.REC, SEL.ERR)
    Y.CUS.LIST = SEL.LIST
    RETURN

*-----------------------------------------------------------------------------
PROCESS.CUSTOMER:
    Y.LINE = '' ; GOSUB SHOW
    Y.LINE = '--- CUSTOMER ':Y.CUS.ID:' ':STR('-', 60) ; GOSUB SHOW
    R.CUS = '' ; Y.READ.ERR = ''
    CALL F.READ(FN.CUSTOMER, Y.CUS.ID, R.CUS, F.CUSTOMER, Y.READ.ERR)
    IF R.CUS = '' THEN
        Y.LINE = 'CUSTOMER ':Y.CUS.ID:' not found' ; GOSUB SHOW
        Y.CNT.ERR += 1
        RETURN
    END

    GOSUB BUILD.PARAM
    Y.LINE = 'Name        : ':Y.NAME ; GOSUB SHOW
    Y.LINE = 'Nationality : ':Y.COUNTRY:'   Year of birth: ':Y.YOB:'   Gender: ':Y.GENDER:'   Legal ID: ':Y.CLIENT.ID ; GOSUB SHOW
    Y.LINE = 'CALLJ param : ':Y.PARAM ; GOSUB SHOW

    Y.DECISION = '' ; Y.MESSAGE = '' ; Y.ONBOARD.NO = ''
    CALL AML.SCAN.CUSTOMER(Y.PARAM, Y.DECISION, Y.MESSAGE, Y.ONBOARD.NO)

    BEGIN CASE
        CASE Y.DECISION = 'PASS'
            Y.CNT.PASS += 1
            Y.LINE = '=> PASS     : ':Y.MESSAGE
        CASE Y.DECISION = 'OVERRIDE'
            Y.CNT.OVR += 1
            Y.LINE = '=> OVERRIDE : ':Y.MESSAGE
        CASE Y.DECISION = 'BLOCK'
            Y.CNT.BLOCK += 1
            Y.LINE = '=> BLOCK    : ':Y.MESSAGE
        CASE 1
            Y.CNT.ERR += 1
            Y.LINE = '=> ERROR    : ':Y.MESSAGE
    END CASE
    GOSUB SHOW
    IF Y.ONBOARD.NO NE '' THEN Y.HIT.LIST<-1> = Y.CUS.ID:'*':Y.ONBOARD.NO
    RETURN

*-----------------------------------------------------------------------------
BUILD.PARAM:
* RealTimeScanRequest: 19 fields separated by '@'
    Y.NAME = R.CUS<EB.CUS.NAME.1, 1>
    IF Y.NAME = '' THEN Y.NAME = R.CUS<EB.CUS.SHORT.NAME, 1>
    Y.COUNTRY = R.CUS<EB.CUS.NATIONALITY>
    Y.YOB = R.CUS<EB.CUS.DATE.OF.BIRTH>[1,4]
    Y.GENDER = R.CUS<EB.CUS.GENDER>[1,1]                        ;* MALE -> M, FEMALE -> F
    Y.CLIENT.ID = R.CUS<EB.CUS.LEGAL.ID, 1>
    IF Y.CLIENT.ID = '' THEN Y.CLIENT.ID = Y.CUS.ID                ;* ClientID is mandatory
    Y.PASSPORT = ''
    IF R.CUS<EB.CUS.LEGAL.DOC.NAME, 1> = 'PASSPORT' THEN Y.PASSPORT = Y.CLIENT.ID

    Y.PARAM = OPERATOR[1,50]:'@':ID.COMPANY:'@CBS@':Y.CUS.ID:'@1@Y@I@Y'
    Y.PARAM := '@':Y.NAME[1,150]:'@':Y.COUNTRY:'@':Y.YOB:'@':Y.GENDER
    Y.PARAM := '@':Y.CUS.ID:'@':Y.CLIENT.ID:'@':Y.PASSPORT:'@@@@2#KH|KH|02|0|0|1|0'
    RETURN

*-----------------------------------------------------------------------------
CHECK.HITS:
    IF Y.HIT.LIST = '' THEN RETURN
    Y.LINE = '' ; GOSUB SHOW
    Y.LINE = '--- Approval status of AML hits ':STR('-', 46) ; GOSUB SHOW
    LOOP
        REMOVE Y.HIT FROM Y.HIT.LIST SETTING Y.HPOS
    WHILE Y.HIT : Y.HPOS
        Y.REF = FIELD(Y.HIT, '*', 1)
        Y.ONB = FIELD(Y.HIT, '*', 2)
        Y.LINE = 'CUSTOMER ':Y.REF:' / OnboardNo ':Y.ONB ; GOSUB SHOW
        GOSUB CHECK.APPROVAL
    REPEAT
    RETURN

*-----------------------------------------------------------------------------
CHECK.APPROVAL:
* RealTimeApprovalStatusRequest: OfficerId@Location@Source@ReferenceNo@OnboardNo
    Y.AP.PARAM = OPERATOR[1,50]:'@':ID.COMPANY:'@CBS@':Y.REF:'@':Y.ONB
    Y.AP.RESULT = '' ; Y.AP.ERROR = ''
    CALL AML.CALLJ.INVOKE('callRealTimeApprovalStatus', Y.AP.PARAM, Y.AP.RESULT, Y.AP.ERROR)
    IF Y.AP.ERROR NE '' THEN
        Y.LINE = '  Approval : ERROR ':Y.AP.ERROR
    END ELSE
        Y.STATUS = FIELD(Y.AP.RESULT, '#', 1)
        BEGIN CASE
            CASE Y.STATUS = 'A'
                Y.STATUS.DESC = 'APPROVED'
            CASE Y.STATUS = 'R'
                Y.STATUS.DESC = 'REJECTED'
            CASE Y.STATUS = 'P'
                Y.STATUS.DESC = 'PENDING - waiting for Compliance review'
            CASE 1
                Y.STATUS.DESC = 'NOT FOUND'
        END CASE
        Y.LINE = '  Approval : ':Y.STATUS:' (':Y.STATUS.DESC:')'
    END
    GOSUB SHOW

* RealTimeExposureRequest: OfficerID@Location@Source@OnboardNo
    Y.EX.PARAM = OPERATOR[1,50]:'@':ID.COMPANY:'@CBS@':Y.ONB
    Y.EX.RESULT = '' ; Y.EX.ERROR = ''
    CALL AML.CALLJ.INVOKE('callRealTimeExposure', Y.EX.PARAM, Y.EX.RESULT, Y.EX.ERROR)
    IF Y.EX.ERROR NE '' THEN
        Y.LINE = '  Exposure : ERROR ':Y.EX.ERROR
    END ELSE
        Y.LINE = '  Exposure : ':FIELD(Y.EX.RESULT, '#', 1):'  Watchlist=':FIELD(Y.EX.RESULT, '#', 2):'  PEP/RCA=':FIELD(Y.EX.RESULT, '#', 4)
    END
    GOSUB SHOW
    RETURN
END
