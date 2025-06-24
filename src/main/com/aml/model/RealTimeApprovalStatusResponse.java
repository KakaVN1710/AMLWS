package main.com.aml.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class RealTimeApprovalStatusResponse {

    @JsonProperty("ApprovalStatus")
    private String approvalStatus;

    @JsonProperty("HandShake")
    private String handshake;



    public String getHandshake() {
        return handshake;
    }

    public void setHandshake(String handshake) {
        this.handshake = handshake;
    }

    public String getApprovalStatus() {
        return approvalStatus;
    }

    public void setApprovalStatus(String approvalStatus) {
        this.approvalStatus = approvalStatus;
    }

    public String toDelimitedString() {
        return String.join("#",
                nonNull(approvalStatus),
                nonNull(handshake)
        );
    }

    private String nonNull(String value) {
        return value == null ? "" : value;
    }
}
