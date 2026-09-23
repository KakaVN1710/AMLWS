    SUBROUTINE V.AML.SCAN.CUSTOMER
*-----------------------------------------------------------------------------
* INPUT ROUTINE gan vao VERSION CUSTOMER,AML.INPUT (truong INPUT.ROUTINE)
* Chi dung tren T24 that (TAFJ) - trinh gia lap khong ho tro R.NEW/STORE.OVERRIDE.
*
*   CUSTOMER commit --> V.AML.SCAN.CUSTOMER --> AML.SCAN.CUSTOMER
*                   --> AML.CALLJ.INVOKE --CALLJ--> main.com.aml.AmlClient.callRealTimeScan
*
*   PASS     : cho commit binh thuong
*   OVERRIDE : sinh override (nguoi dung phai chap nhan)
*   BLOCK    : bao loi, khong cho commit
*   ERROR    : loi tich hop -> bao loi (tuy chinh sach co the doi thanh override)
*-----------------------------------------------------------------------------
    $INSERT I_COMMON
    $INSERT I_EQUATE
    $INSERT I_F.CUSTOMER

    IF V$FUNCTION NE 'I' THEN RETURN

    GOSUB BUILD.PARAM
    GOSUB CALL.AML
    RETURN

*-----------------------------------------------------------------------------
BUILD.PARAM:
    Y.OFFICER = OPERATOR
    Y.LOCATION = ID.COMPANY
    Y.SOURCE = 'CBS'
    Y.REF = ID.NEW
    Y.SERVICE.TYPE = '1'
    Y.REDFLAG = 'Y'
    Y.CLIENT.TYPE = 'I'
    IF R.OLD(EB.CUS.SHORT.NAME) = '' THEN Y.CLIENT.EXIST = 'N' ELSE Y.CLIENT.EXIST = 'Y'
    Y.NAME = R.NEW(EB.CUS.NAME.1)<1,1>
    IF Y.NAME = '' THEN Y.NAME = R.NEW(EB.CUS.SHORT.NAME)<1,1>
    Y.COUNTRY = R.NEW(EB.CUS.NATIONALITY)
    Y.YOB = R.NEW(EB.CUS.DATE.OF.BIRTH)[1,4]
    Y.GENDER = R.NEW(EB.CUS.GENDER)[1,1]           ;* MALE -> M, FEMALE -> F
    Y.CLIENT.NO = ''
    IF Y.CLIENT.EXIST = 'Y' THEN Y.CLIENT.NO = ID.NEW
    Y.CLIENT.ID = R.NEW(EB.CUS.LEGAL.ID)<1,1>
    Y.PASSPORT = ''
    IF R.NEW(EB.CUS.LEGAL.DOC.NAME)<1,1> = 'PASSPORT' THEN Y.PASSPORT = Y.CLIENT.ID
    Y.RISK.FACTOR = '2#KH|KH|02|0|0|1|0'            ;* TODO: tinh tu du lieu KYC cua ngan hang

    Y.PARAM = Y.OFFICER:'@':Y.LOCATION:'@':Y.SOURCE:'@':Y.REF:'@':Y.SERVICE.TYPE
    Y.PARAM := '@':Y.REDFLAG:'@':Y.CLIENT.TYPE:'@':Y.CLIENT.EXIST:'@':Y.NAME
    Y.PARAM := '@':Y.COUNTRY:'@':Y.YOB:'@':Y.GENDER:'@':Y.CLIENT.NO:'@':Y.CLIENT.ID
    Y.PARAM := '@':Y.PASSPORT:'@@@@':Y.RISK.FACTOR
    RETURN

*-----------------------------------------------------------------------------
CALL.AML:
    Y.DECISION = '' ; Y.MESSAGE = '' ; Y.ONBOARD.NO = ''
    CALL AML.SCAN.CUSTOMER(Y.PARAM, Y.DECISION, Y.MESSAGE, Y.ONBOARD.NO)

    BEGIN CASE
        CASE Y.DECISION = 'PASS'
            NULL
        CASE Y.DECISION = 'OVERRIDE'
            TEXT = Y.MESSAGE
            CURR.NO = DCOUNT(R.NEW(V-9), VM) + 1
            CALL STORE.OVERRIDE(CURR.NO)
        CASE Y.DECISION = 'BLOCK'
            AF = EB.CUS.NATIONALITY
            ETEXT = Y.MESSAGE
            CALL STORE.END.ERROR
        CASE 1
            AF = EB.CUS.SHORT.NAME
            ETEXT = 'AML scan failed: ':Y.MESSAGE
            CALL STORE.END.ERROR
    END CASE
    RETURN
END
