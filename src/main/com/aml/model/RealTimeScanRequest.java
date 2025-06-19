package main.com.aml.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class RealTimeScanRequest {
    @JsonProperty("OfficerId")
    private String officerId;

    @JsonProperty("Location")
    private String location;

    @JsonProperty("Source")
    private String source;

    @JsonProperty("ReferenceNo")
    private String referenceNo;

    @JsonProperty("ServiceType")
    private String serviceType;

    @JsonProperty("RedFlagType")
    private String redFlagType;

    @JsonProperty("ClientType")
    private String clientType;

    @JsonProperty("ClientExist")
    private String clientExist;

    @JsonProperty("ClientName")
    private String clientName;

    @JsonProperty("ClientCountry")
    private String clientCountry;

    @JsonProperty("ClientYOB")
    private String clientYob;

    @JsonProperty("ClientGender")
    private String clientGender;

    @JsonProperty("ClientNo")
    private String clientNo;

    @JsonProperty("ClientID")
    private String clientId;

    @JsonProperty("PassportNo")
    private String passportNo;

    @JsonProperty("PassportNoSec")
    private String passportNoSec;

    @JsonProperty("PassportExpDate")
    private String passportExpDate;

    @JsonProperty("PassportExpDateSec")
    private String passportExpDateSec;

    @JsonProperty("RiskFactor")
    private String riskFactor;

    // Constructor private
    private RealTimeScanRequest() {}

    // ----- GETTERS & SETTERS -----

    public static class Builder {
        private String officerId;
        private String location;
        private String source;
        private String referenceNo;
        private String serviceType;
        private String redFlagType;
        private String clientType;
        private String clientExist;
        private String clientName;
        private String clientCountry;
        private String clientYob;
        private String clientGender;
        private String clientNo;
        private String clientId;
        private String passportNo;
        private String passportNoSec;
        private String passportExpDate;
        private String passportExpDateSec;
        private String riskFactor;


        public Builder officerId(String officerId) {
            this.officerId = officerId;
            return this;
        }
        public Builder location(String location) {
            this.location = location;
            return this;
        }
        public Builder source(String source) {
            this.source = source;
            return this;
        }
        public Builder referenceNo(String referenceNo) {
            this.referenceNo = referenceNo;
            return this;
        }
        public Builder serviceType(String serviceType) {
            this.serviceType = serviceType;
            return this;
        }
        public Builder redFlagType(String redFlagType) {
            this.redFlagType = redFlagType;
            return this;
        }
        public Builder clientType(String clientType) {
            this.clientType = clientType;
            return this;
        }
        public Builder clientExist(String clientExist) {
            this.clientExist = clientExist;
            return this;
        }
        public Builder clientName(String clientName) {
            this.clientName = clientName;
            return this;
        }
        public Builder clientCountry(String clientCountry) {
            this.clientCountry = clientCountry;
            return this;
        }
        public Builder clientYob(String clientYob) {
            this.clientYob = clientYob;
            return this;
        }
        public Builder clientGender(String clientGender) {
            this.clientGender = clientGender;
            return this;
        }
        public Builder clientNo(String clientNo) {
            this.clientNo = clientNo;
            return this;
        }
        public Builder clientId(String clientId) {
            this.clientId = clientId;
            return this;
        }
        public Builder passportNo(String passportNo) {
            this.passportNo = passportNo;
            return this;
        }
        public Builder passportNoSec(String passportNoSec) {
            this.passportNoSec = passportNoSec;
            return this;
        }
        public Builder passportExpDate(String passportExpDate) {
            this.passportExpDate = passportExpDate;
            return this;
        }
        public Builder passportExpDateSec(String passportExpDateSec) {
            this.passportExpDateSec = passportExpDateSec;
            return this;
        }
        public Builder riskFactor(String riskFactor) {
            this.riskFactor = riskFactor;
            return this;
        }

        public RealTimeScanRequest build() {
            // Validation required fields
            checkRequired(officerId, "OfficerId", 50);
            checkRequired(location, "Location", 10);
            checkRequired(source, "Source", 20);
            checkRequired(referenceNo, "ReferenceNo", 50);
            checkRequired(serviceType, "ServiceType", 5);
            checkRequired(redFlagType, "RedFlagType", 1);
            checkRequired(clientName, "ClientName", 150);
            checkRequired(clientId, "ClientID", 50);
            checkRequired(riskFactor, "RiskFactor", 100);

            // Optional fields length check
            checkOptional(clientType, "ClientType", 1);
            checkOptional(clientExist, "ClientExist", 1);
            checkOptional(clientCountry, "ClientCountry", 3);
            checkOptional(clientYob, "ClientYOB", 4);
            checkOptional(clientGender, "ClientGender", 2);
            checkOptional(clientNo, "ClientNo", 50);
            checkOptional(passportNo, "PassportNo", 50);
            checkOptional(passportNoSec, "PassportNoSec", 5);
            checkOptional(passportExpDate, "PassportExpDate", 10);
            checkOptional(passportExpDateSec, "PassportExpDateSec", 5);

            RealTimeScanRequest req = new RealTimeScanRequest();
            req.officerId = this.officerId;
            req.location = this.location;
            req.source = this.source;
            req.referenceNo = this.referenceNo;
            req.serviceType = this.serviceType;
            req.redFlagType = this.redFlagType;
            req.clientType = this.clientType;
            req.clientExist = this.clientExist;
            req.clientName = this.clientName;
            req.clientCountry = this.clientCountry;
            req.clientYob = this.clientYob;
            req.clientGender = this.clientGender;
            req.clientNo = this.clientNo;
            req.clientId = this.clientId;
            req.passportNo = this.passportNo;
            req.passportNoSec = this.passportNoSec;
            req.passportExpDate = this.passportExpDate;
            req.passportExpDateSec = this.passportExpDateSec;
            req.riskFactor = this.riskFactor;

            return req;
        }

        public static RealTimeScanRequest fromDelimitedString(String input) {
            String[] parts = input.split("@", -1);

            if (parts.length < 19) {
                throw new IllegalArgumentException("Invalid number of parameters. Expected 19, got " + parts.length);
            }

            return new RealTimeScanRequest.Builder()
                    .officerId(parts[0])
                    .location(parts[1])
                    .source(parts[2])
                    .referenceNo(parts[3])
                    .serviceType(parts[4])
                    .redFlagType(parts[5])
                    .clientType(parts[6])
                    .clientExist(parts[7])
                    .clientName(parts[8])
                    .clientCountry(parts[9])
                    .clientYob(parts[10])
                    .clientGender(parts[11])
                    .clientNo(parts[12])
                    .clientId(parts[13])
                    .passportNo(parts[14])
                    .passportNoSec(parts[15])
                    .passportExpDate(parts[16])
                    .passportExpDateSec(parts[17])
                    .riskFactor(parts[18])
                    .build();
        }

        private void checkRequired(String value, String fieldName, int maxLength) {
            if (value == null || value.trim().isEmpty()) {
                throw new IllegalArgumentException(fieldName + " is required");
            }
            if (value.length() > maxLength) {
                throw new IllegalArgumentException(fieldName + " max length exceeded (" + maxLength + ")");
            }
        }

        private void checkOptional(String value, String fieldName, int maxLength) {
            if (value != null && value.length() > maxLength) {
                throw new IllegalArgumentException(fieldName + " max length exceeded (" + maxLength + ")");
            }
        }
    }
}
