    PROGRAM CALLJ.HELLO
*-----------------------------------------------------------------------------
* Basic CALLJ example (CALLJ training, section 4):
*   calls public static String com.temenos.training.HelloWorld.greet(String)
* TAFJ / jBASE syntax:
*   CALLJ <class>, [$]<method>, <param> SETTING <ret> [ON ERROR ...]
*   - '$' before the method name = static method
*-----------------------------------------------------------------------------
    V.REPLY = ''
    CALLJ "com.temenos.training.HelloWorld", "$greet", "T24 Developer" SETTING V.REPLY ON ERROR
        CRT "CALLJ error, SYSTEM(0) = ":SYSTEM(0)
        STOP
    END
    CRT "Result from Java: ":V.REPLY
END
