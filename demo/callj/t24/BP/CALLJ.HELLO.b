    PROGRAM CALLJ.HELLO
*-----------------------------------------------------------------------------
* Vi du CALLJ co ban (muc 4 tai lieu CALLJ Training):
*   Goi public static String com.temenos.training.HelloWorld.greet(String)
* Luu y cu phap that cua TAFJ/jBASE:
*   CALLJ <class>, [$]<method>, <param> SETTING <ret> [ON ERROR ...]
*   - '$' truoc ten method = static method
*-----------------------------------------------------------------------------
    V.REPLY = ''
    CALLJ "com.temenos.training.HelloWorld", "$greet", "T24 Developer" SETTING V.REPLY ON ERROR
        CRT "CALLJ error, SYSTEM(0) = ":SYSTEM(0)
        STOP
    END
    CRT "Result from Java: ":V.REPLY
END
