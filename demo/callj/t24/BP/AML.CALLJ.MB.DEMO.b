    PROGRAM AML.CALLJ.MB.DEMO
*-----------------------------------------------------------------------------
* MAINLINE demo CALLJ tren T24 Model Bank (TAFJ) -> AmlClient -> Mock AML server
*
* Cach chay (tu thu muc bin cua TAFJ):
*   tRun AML.CALLJ.MB.DEMO                 quet 5 khach hang bat ky trong CUSTOMER
*   tRun AML.CALLJ.MB.DEMO 100100 100724   quet cac khach hang chi dinh
*
* Voi moi khach hang: doc record CUSTOMER that -> dung chuoi tham so '@'
*   -> CALL AML.SCAN.CUSTOMER -> CALLJ main.com.aml.AmlClient.$callRealTimeScan
*   -> in ket qua PASS / OVERRIDE / BLOCK / ERROR
* Khach hang bi hit se duoc hoi tiep trang thai phe duyet + exposure.
*
* Can compile kem: AML.SCAN.CUSTOMER, AML.CALLJ.INVOKE, AML.CHECK.APPROVAL.SUB
*-----------------------------------------------------------------------------
    $INSERT I_COMMON
    $INSERT I_EQUATE
    $INSERT I_F.CUSTOMER

    GOSUB INITIALISE.SESSION
    GOSUB OPEN.FILES
    GOSUB GET.CUSTOMER.LIST

    CRT STR('=', 78)
    CRT ' DEMO CALLJ TREN T24 MODEL BANK -> AML          ':TIMEDATE()
    CRT ' Company: ':ID.COMPANY:'   Operator: ':OPERATOR:'   So KH: ':DCOUNT(Y.CUS.LIST, FM)
    CRT STR('=', 78)

    Y.CNT.PASS = 0 ; Y.CNT.OVR = 0 ; Y.CNT.BLOCK = 0 ; Y.CNT.ERR = 0
    Y.HIT.LIST = ''
    LOOP
        REMOVE Y.CUS.ID FROM Y.CUS.LIST SETTING Y.POS
    WHILE Y.CUS.ID : Y.POS
        GOSUB PROCESS.CUSTOMER
    REPEAT

    GOSUB CHECK.HITS

    CRT
    CRT STR('=', 78)
    CRT ' TONG KET: PASS=':Y.CNT.PASS:'  OVERRIDE=':Y.CNT.OVR:'  BLOCK=':Y.CNT.BLOCK:'  ERROR=':Y.CNT.ERR
    CRT STR('=', 78)
    STOP

*-----------------------------------------------------------------------------
INITIALISE.SESSION:
* Khi chay bang tRun (ngoai phien Browser) phai tu khoi tao common T24.
* JF.INITIALISE.CONNECTION can bien moi truong OFS_SOURCE = ID mot record OFS.SOURCE
*   vd:  set OFS_SOURCE=OFSONLINE   (xem cac ID co san: LIST F.OFS.SOURCE)
    Y.OFS.SOURCE = ''
    IF NOT(GETENV('OFS_SOURCE', Y.OFS.SOURCE)) THEN Y.OFS.SOURCE = ''
    IF Y.OFS.SOURCE = '' THEN
        CRT 'Chua set bien moi truong OFS_SOURCE (can cho JF.INITIALISE.CONNECTION).'
        CRT 'Vi du:  set OFS_SOURCE=OFSONLINE   roi chay lai tRun AML.CALLJ.MB.DEMO'
        CRT 'Xem cac OFS.SOURCE co san:  LIST F.OFS.SOURCE'
        STOP
    END
    CRT 'OFS_SOURCE = ':Y.OFS.SOURCE
    CALL JF.INITIALISE.CONNECTION
    IF ID.COMPANY = '' THEN CALL LOAD.COMPANY('GB0010001')      ;* company mac dinh Model Bank
    IF OPERATOR = '' THEN OPERATOR = 'INPUTTER'
    RETURN

*-----------------------------------------------------------------------------
OPEN.FILES:
    FN.CUSTOMER = 'F.CUSTOMER'
    F.CUSTOMER = ''
    CALL OPF(FN.CUSTOMER, F.CUSTOMER)
    RETURN

*-----------------------------------------------------------------------------
GET.CUSTOMER.LIST:
* Tham so dong lenh: tRun AML.CALLJ.MB.DEMO <id1> <id2> ...
    Y.CUS.LIST = ''
    Y.CMD = TRIM(SENTENCE())
    Y.NB.WORDS = DCOUNT(Y.CMD, ' ')
    FOR Y.I = 2 TO Y.NB.WORDS
        Y.CUS.LIST<-1> = FIELD(Y.CMD, ' ', Y.I)
    NEXT Y.I

    IF Y.CUS.LIST = '' THEN
        SEL.CMD = 'SELECT ':FN.CUSTOMER:' SAMPLE 5'
        SEL.LIST = '' ; NO.OF.REC = 0 ; SEL.ERR = ''
        CALL EB.READLIST(SEL.CMD, SEL.LIST, '', NO.OF.REC, SEL.ERR)
        Y.CUS.LIST = SEL.LIST
    END
    RETURN

*-----------------------------------------------------------------------------
PROCESS.CUSTOMER:
    CRT
    CRT '--- CUSTOMER ':Y.CUS.ID:' ':STR('-', 60)
    R.CUS = '' ; Y.READ.ERR = ''
    CALL F.READ(FN.CUSTOMER, Y.CUS.ID, R.CUS, F.CUSTOMER, Y.READ.ERR)
    IF R.CUS = '' THEN
        CRT 'Khong tim thay CUSTOMER ':Y.CUS.ID
        Y.CNT.ERR += 1
        RETURN
    END

    GOSUB BUILD.PARAM
    CRT 'Ten        : ':Y.NAME
    CRT 'Quoc tich  : ':Y.COUNTRY:'   Nam sinh: ':Y.YOB:'   Gioi tinh: ':Y.GENDER:'   Legal ID: ':Y.CLIENT.ID
    CRT 'CALLJ param: ':Y.PARAM

    Y.DECISION = '' ; Y.MESSAGE = '' ; Y.ONBOARD.NO = ''
    CALL AML.SCAN.CUSTOMER(Y.PARAM, Y.DECISION, Y.MESSAGE, Y.ONBOARD.NO)

    BEGIN CASE
        CASE Y.DECISION = 'PASS'
            Y.CNT.PASS += 1
            CRT '=> PASS     : ':Y.MESSAGE
        CASE Y.DECISION = 'OVERRIDE'
            Y.CNT.OVR += 1
            CRT '=> OVERRIDE : ':Y.MESSAGE
        CASE Y.DECISION = 'BLOCK'
            Y.CNT.BLOCK += 1
            CRT '=> BLOCK    : ':Y.MESSAGE
        CASE 1
            Y.CNT.ERR += 1
            CRT '=> ERROR    : ':Y.MESSAGE
    END CASE
    IF Y.ONBOARD.NO NE '' THEN Y.HIT.LIST<-1> = Y.CUS.ID:'*':Y.ONBOARD.NO
    RETURN

*-----------------------------------------------------------------------------
BUILD.PARAM:
* RealTimeScanRequest: 19 truong phan cach '@'
    Y.NAME = R.CUS<EB.CUS.NAME.1, 1>
    IF Y.NAME = '' THEN Y.NAME = R.CUS<EB.CUS.SHORT.NAME, 1>
    Y.COUNTRY = R.CUS<EB.CUS.NATIONALITY>
    Y.YOB = R.CUS<EB.CUS.DATE.OF.BIRTH>[1,4]
    Y.GENDER = R.CUS<EB.CUS.GENDER>[1,1]                        ;* MALE -> M, FEMALE -> F
    Y.CLIENT.ID = R.CUS<EB.CUS.LEGAL.ID, 1>
    IF Y.CLIENT.ID = '' THEN Y.CLIENT.ID = Y.CUS.ID                ;* ClientID bat buoc
    Y.PASSPORT = ''
    IF R.CUS<EB.CUS.LEGAL.DOC.NAME, 1> = 'PASSPORT' THEN Y.PASSPORT = Y.CLIENT.ID

    Y.PARAM = OPERATOR[1,50]:'@':ID.COMPANY:'@CBS@':Y.CUS.ID:'@1@Y@I@Y'
    Y.PARAM := '@':Y.NAME[1,150]:'@':Y.COUNTRY:'@':Y.YOB:'@':Y.GENDER
    Y.PARAM := '@':Y.CUS.ID:'@':Y.CLIENT.ID:'@':Y.PASSPORT:'@@@@2#KH|KH|02|0|0|1|0'
    RETURN

*-----------------------------------------------------------------------------
CHECK.HITS:
    IF Y.HIT.LIST = '' THEN RETURN
    CRT
    CRT '--- Kiem tra phe duyet cac ho so bi hit ':STR('-', 38)
    LOOP
        REMOVE Y.HIT FROM Y.HIT.LIST SETTING Y.HPOS
    WHILE Y.HIT : Y.HPOS
        Y.REF = FIELD(Y.HIT, '*', 1)
        Y.ONB = FIELD(Y.HIT, '*', 2)
        CRT 'CUSTOMER ':Y.REF:' / OnboardNo ':Y.ONB
        CALL AML.CHECK.APPROVAL.SUB(Y.REF, Y.ONB)
    REPEAT
    RETURN
END
