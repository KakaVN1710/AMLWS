    PROGRAM AML.CHECK.APPROVAL
*-----------------------------------------------------------------------------
* Usage: AML.CHECK.APPROVAL <ReferenceNo> <OnboardNo>
*-----------------------------------------------------------------------------
    Y.REF = FIELD(@SENTENCE, ' ', 2)
    Y.ONBOARD.NO = FIELD(@SENTENCE, ' ', 3)
    IF Y.ONBOARD.NO = '' THEN
        CRT 'Usage: AML.CHECK.APPROVAL <ReferenceNo> <OnboardNo>'
        STOP
    END
    CRT 'Checking AML case OnboardNo=':Y.ONBOARD.NO:' ReferenceNo=':Y.REF
    CALL AML.CHECK.APPROVAL.SUB(Y.REF, Y.ONBOARD.NO)
END
