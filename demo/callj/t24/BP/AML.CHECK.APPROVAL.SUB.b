    SUBROUTINE AML.CHECK.APPROVAL.SUB(Y.REF, Y.ONBOARD.NO)
*-----------------------------------------------------------------------------
* Queries the approval status (RealTimeApproval) and the exposure
* (RealTimeExposure) of an AML case through CALLJ
*-----------------------------------------------------------------------------
    Y.OFFICER = 'SBI602640'
    Y.LOCATION = 'KH0010001'
    Y.SOURCE = 'CBS'

* RealTimeApprovalStatusRequest: OfficerId@Location@Source@ReferenceNo@OnboardNo
    Y.PARAM = Y.OFFICER:'@':Y.LOCATION:'@':Y.SOURCE:'@':Y.REF:'@':Y.ONBOARD.NO
    Y.RESULT = '' ; Y.ERROR = ''
    CALL AML.CALLJ.INVOKE('callRealTimeApprovalStatus', Y.PARAM, Y.RESULT, Y.ERROR)
    IF Y.ERROR NE '' THEN
        CRT 'Approval   : ERROR ':Y.ERROR
    END ELSE
        Y.STATUS = FIELD(Y.RESULT, '#', 1)
        BEGIN CASE
            CASE Y.STATUS = 'A'
                Y.STATUS.DESC = 'APPROVED - relationship can be opened'
            CASE Y.STATUS = 'R'
                Y.STATUS.DESC = 'REJECTED - customer declined'
            CASE Y.STATUS = 'P'
                Y.STATUS.DESC = 'PENDING - waiting for Compliance review'
            CASE 1
                Y.STATUS.DESC = 'NOT FOUND'
        END CASE
        CRT 'Approval   : ':Y.STATUS:' (':Y.STATUS.DESC:'), HandShake=':FIELD(Y.RESULT, '#', 2)
    END

* RealTimeExposureRequest: OfficerID@Location@Source@OnboardNo
    Y.PARAM = Y.OFFICER:'@':Y.LOCATION:'@':Y.SOURCE:'@':Y.ONBOARD.NO
    Y.RESULT = '' ; Y.ERROR = ''
    CALL AML.CALLJ.INVOKE('callRealTimeExposure', Y.PARAM, Y.RESULT, Y.ERROR)
    IF Y.ERROR NE '' THEN
        CRT 'Exposure   : ERROR ':Y.ERROR
    END ELSE
        CRT 'Exposure   : ':FIELD(Y.RESULT, '#', 1)
        CRT '             Watchlist=':FIELD(Y.RESULT, '#', 2):' (':FIELD(Y.RESULT, '#', 3):'), PEP/RCA=':FIELD(Y.RESULT, '#', 4):' (':FIELD(Y.RESULT, '#', 5):')'
    END
    RETURN
END
