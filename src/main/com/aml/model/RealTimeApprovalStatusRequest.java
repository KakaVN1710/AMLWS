package main.com.aml.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class RealTimeApprovalStatusRequest {
    @JsonProperty("OfficerId")
    private String officerID;
    @JsonProperty("Location")
    private String location;
    @JsonProperty("Source")
    private String source;
    @JsonProperty("ReferenceNo")
    private String referenceNo;
    @JsonProperty("OnboardNo")
    private String onboardNo;

    public String getOfficerID() {
        return officerID;
    }

    public void setOfficerID(String officerID) {
        this.officerID = officerID;
    }

    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public String getReferenceNo() {
        return referenceNo;
    }

    public void setReferenceNo(String referenceNo) {
        this.referenceNo = referenceNo;
    }

    public String getOnboardNo() {
        return onboardNo;
    }

    public void setOnboardNo(String onboardNo) {
        this.onboardNo = onboardNo;
    }

    public static class Builder {
        public static RealTimeApprovalStatusRequest fromDelimitedString(String input) {

            String[] parts = input.split("@", -1);

            if (parts.length < 5) {
                throw new IllegalArgumentException("Invalid number of parameters. Expected 5, got " + parts.length);
            }

            RealTimeApprovalStatusRequest req = new RealTimeApprovalStatusRequest();
            req.setOfficerID(parts[0]);
            req.setLocation(parts[1]);
            req.setSource(parts[2]);
            req.setReferenceNo(parts[3]);
            req.setOnboardNo(parts[4]);

            return req;
        }
    }

}
