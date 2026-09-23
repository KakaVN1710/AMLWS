    SUBROUTINE AML.CALLJ.INVOKE(Y.METHOD, Y.PARAM, Y.RESULT, Y.ERROR)
*-----------------------------------------------------------------------------
* CALLJ wrapper for main.com.aml.AmlClient (aml-integration-full.jar)
*
* IN  : Y.METHOD  callRealTimeScan | callRealTimeApprovalStatus | callRealTimeExposure
*       Y.PARAM   request fields separated by '@'
* OUT : Y.RESULT  response fields separated by '#'
*       Y.ERROR   empty on success, otherwise the error description
*
* TAFJ deployment: aml-integration-full.jar and its libraries on the TAFJ
* classpath, aml.properties on the classpath (embedded in the demo jar).
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

* On failure AmlClient returns JSON ({"error": "..."} or the API error body).
* A valid result is always '#' delimited and never starts with '{'.
    IF Y.RET[1,1] = '{' THEN
        Y.ERROR = 'AML-API ':Y.RET
        RETURN
    END

    Y.RESULT = Y.RET
    RETURN
END
