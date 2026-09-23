    SUBROUTINE AML.CALLJ.INVOKE(Y.METHOD, Y.PARAM, Y.RESULT, Y.ERROR)
*-----------------------------------------------------------------------------
* Wrapper CALLJ -> main.com.aml.AmlClient (aml-integration-full.jar)
*
* IN  : Y.METHOD  callRealTimeScan | callRealTimeApprovalStatus | callRealTimeExposure
*       Y.PARAM   chuoi tham so, cac truong phan cach boi '@'
* OUT : Y.RESULT  chuoi ket qua, cac truong phan cach boi '#'
*       Y.ERROR   rong neu thanh cong, nguoc lai la mo ta loi
*
* Trien khai tren TAFJ: copy aml-integration-full.jar + libs vao classpath
* (vd <TAFJ_HOME>/ext hoac BNK_EJB/lib), aml.properties dat trong classpath.
*-----------------------------------------------------------------------------
    Y.RESULT = ''
    Y.ERROR = ''
    Y.RET = ''
    Y.CLASS = 'main.com.aml.AmlClient'
    Y.JMETHOD = '$':Y.METHOD                ;* '$' = public static String method(String)

    CALLJ Y.CLASS, Y.JMETHOD, Y.PARAM SETTING Y.RET ON ERROR
        Y.ERR.CODE = SYSTEM(0)
        BEGIN CASE
            CASE Y.ERR.CODE = 1
                Y.ERROR = 'CALLJ-1 Fatal error creating thread'
            CASE Y.ERR.CODE = 2
                Y.ERROR = 'CALLJ-2 Cannot create JVM'
            CASE Y.ERR.CODE = 3
                Y.ERROR = 'CALLJ-3 Cannot find class ':Y.CLASS
            CASE Y.ERR.CODE = 4
                Y.ERROR = 'CALLJ-4 Unicode conversion error'
            CASE Y.ERR.CODE = 5
                Y.ERROR = 'CALLJ-5 Cannot find method ':Y.JMETHOD
            CASE Y.ERR.CODE = 6
                Y.ERROR = 'CALLJ-6 Cannot find object constructor'
            CASE Y.ERR.CODE = 7
                Y.ERROR = 'CALLJ-7 Cannot instantiate object'
            CASE 1
                Y.ERROR = 'CALLJ-':Y.ERR.CODE:' Unknown CALLJ error'
        END CASE
    END
    IF Y.ERROR NE '' THEN RETURN

* AmlClient tra ve JSON khi loi (vd {"error": "..."} hoac body loi cua API)
* Ket qua hop le luon la chuoi phan cach '#', khong bat dau bang '{'
    IF Y.RET[1,1] = '{' THEN
        Y.ERROR = 'AML-API ':Y.RET
        RETURN
    END

    Y.RESULT = Y.RET
    RETURN
END
