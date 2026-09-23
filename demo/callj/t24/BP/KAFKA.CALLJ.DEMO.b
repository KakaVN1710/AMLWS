    SUBROUTINE KAFKA.CALLJ.DEMO
*-----------------------------------------------------------------------------
* MAINLINE (no-argument SUBROUTINE): T24 -> CALLJ -> Kafka
*
* Publishes three sample T24 business events to Kafka and prints the
* acknowledgement returned by the broker (topic / partition / offset).
* No T24 file is read, so no session initialisation (OFS_SOURCE) is needed:
*     tRun KAFKA.CALLJ.DEMO
*
* Compile together with: KAFKA.CALLJ.PUBLISH
* Java side: com.demo.kafka.KafkaPublisher (callj-kafka.jar) + kafka-clients jar
*-----------------------------------------------------------------------------
    $INSERT I_COMMON
    $INSERT I_EQUATE

    Y.COMPANY = ID.COMPANY
    IF Y.COMPANY = '' THEN Y.COMPANY = 'GB0010001'
    Y.OPERATOR = OPERATOR
    IF Y.OPERATOR = '' THEN Y.OPERATOR = 'INPUTTER'
    Y.TOPIC = ''                                        ;* '' -> demo.topic (t24.callj.demo)
    Y.SEQ = 0
    Y.CNT.OK = 0
    Y.CNT.ERR = 0

    CRT STR('=', 78)
    CRT ' T24 -> CALLJ -> KAFKA DEMO                    ':TIMEDATE()
    CRT ' Company: ':Y.COMPANY:'   Operator: ':Y.OPERATOR
    CRT STR('=', 78)

    Y.EVENT = 'CUSTOMER.UPDATED'
    Y.KEY = '10000083'
    Y.DATA = DQUOTE('customerId'):':':DQUOTE('10000083'):',':DQUOTE('name'):':':DQUOTE('Solomon David'):',':DQUOTE('nationality'):':':DQUOTE('US')
    GOSUB PUBLISH.EVENT

    Y.EVENT = 'ACCOUNT.OPENED'
    Y.KEY = '10000083'
    Y.DATA = DQUOTE('customerId'):':':DQUOTE('10000083'):',':DQUOTE('category'):':':DQUOTE('1001'):',':DQUOTE('currency'):':':DQUOTE('USD')
    GOSUB PUBLISH.EVENT

    Y.EVENT = 'FUNDS.TRANSFER.COMMITTED'
    Y.KEY = 'FT-DEMO-0001'
    Y.DATA = DQUOTE('debitCustomer'):':':DQUOTE('10000083'):',':DQUOTE('amount'):':':DQUOTE('1500.00'):',':DQUOTE('currency'):':':DQUOTE('USD')
    GOSUB PUBLISH.EVENT

    CRT
    CRT STR('=', 78)
    CRT ' SUMMARY: ACKNOWLEDGED BY KAFKA=':Y.CNT.OK:'   FAILED=':Y.CNT.ERR
    CRT STR('=', 78)
    RETURN

*-----------------------------------------------------------------------------
PUBLISH.EVENT:
    Y.SEQ = Y.SEQ + 1
    Y.MESSAGE = '{':DQUOTE('eventType'):':':DQUOTE(Y.EVENT)
    Y.MESSAGE = Y.MESSAGE:',':DQUOTE('source'):':':DQUOTE('T24')
    Y.MESSAGE = Y.MESSAGE:',':DQUOTE('company'):':':DQUOTE(Y.COMPANY)
    Y.MESSAGE = Y.MESSAGE:',':DQUOTE('operator'):':':DQUOTE(Y.OPERATOR)
    Y.MESSAGE = Y.MESSAGE:',':DQUOTE('sequence'):':':Y.SEQ
    Y.MESSAGE = Y.MESSAGE:',':DQUOTE('t24Time'):':':DQUOTE(TIMEDATE())
    Y.MESSAGE = Y.MESSAGE:',':DQUOTE('data'):':{':Y.DATA:'}}'

    CRT
    CRT '--- Event ':Y.SEQ:': ':Y.EVENT:' ':STR('-', 60 - LEN(Y.EVENT))
    CRT 'Key        : ':Y.KEY
    CRT 'Message    : ':Y.MESSAGE

    Y.RESULT = '' ; Y.ERROR = ''
    CALL KAFKA.CALLJ.PUBLISH(Y.TOPIC, Y.KEY, Y.MESSAGE, Y.RESULT, Y.ERROR)
    IF Y.ERROR NE '' THEN
        Y.CNT.ERR = Y.CNT.ERR + 1
        CRT '=> FAILED  : ':Y.ERROR
        RETURN
    END
    Y.CNT.OK = Y.CNT.OK + 1
    CRT '=> RECORDED BY KAFKA: topic=':FIELD(Y.RESULT, '#', 2):'  partition=':FIELD(Y.RESULT, '#', 3):'  offset=':FIELD(Y.RESULT, '#', 4):'  at ':FIELD(Y.RESULT, '#', 5)
    RETURN
END
