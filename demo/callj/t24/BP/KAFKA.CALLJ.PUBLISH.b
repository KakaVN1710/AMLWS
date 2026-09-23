    SUBROUTINE KAFKA.CALLJ.PUBLISH(Y.TOPIC, Y.KEY, Y.MESSAGE, Y.RESULT, Y.ERROR)
*-----------------------------------------------------------------------------
* Publishes one message to Kafka through CALLJ
*   CALLJ "com.demo.kafka.KafkaPublisher", "$publish", "topic@key@message"
*
* IN  : Y.TOPIC    Kafka topic (empty -> demo.topic from kafka.properties)
*       Y.KEY      record key (may be empty)
*       Y.MESSAGE  record value (any text, e.g. JSON)
* OUT : Y.RESULT   OK#topic#partition#offset#timestamp  (Kafka acknowledgement)
*       Y.ERROR    empty on success, otherwise the error description
*-----------------------------------------------------------------------------
    Y.RESULT = ''
    Y.ERROR = ''
    Y.RET = ''
    Y.CLASS = 'com.demo.kafka.KafkaPublisher'
    Y.PARAM = Y.TOPIC:'@':Y.KEY:'@':Y.MESSAGE

    CALLJ Y.CLASS, '$publish', Y.PARAM SETTING Y.RET ON ERROR
        Y.ERROR = 'CALLJ-':SYSTEM(0):' cannot call ':Y.CLASS:' (check the TAFJ classpath)'
    END
    IF Y.ERROR NE '' THEN RETURN

    IF FIELD(Y.RET, '#', 1) NE 'OK' THEN
        Y.ERROR = 'KAFKA ':FIELD(Y.RET, '#', 2, 99)
        RETURN
    END
    Y.RESULT = Y.RET
    RETURN
END
