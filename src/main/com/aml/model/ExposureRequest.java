package main.com.aml.model;

import com.fasterxml.jackson.databind.ObjectMapper;

public class ExposureRequest {
    public String OfficerID;
    public String Location;
    public String Source;
    public String OnboardNo;

    public String toJson() throws Exception {
        return new ObjectMapper().writeValueAsString(this);
    }

    public String getOfficerID() {
        return OfficerID;
    }

    public void setOfficerID(String officerID) {
        OfficerID = officerID;
    }

    public String getLocation() {
        return Location;
    }

    public void setLocation(String location) {
        Location = location;
    }

    public String getSource() {
        return Source;
    }

    public void setSource(String source) {
        Source = source;
    }

    public String getOnboardNo() {
        return OnboardNo;
    }

    public void setOnboardNo(String onboardNo) {
        OnboardNo = onboardNo;
    }

    public static class Builder {
        public static ExposureRequest fromDelimitedString(String input) {

            String[] parts = input.split("@", -1);

            if (parts.length < 4) {
                throw new IllegalArgumentException("Invalid number of parameters. Expected 4, got " + parts.length);
            }

            ExposureRequest req = new ExposureRequest();
            req.setOfficerID(parts[0]);
            req.setLocation(parts[1]);
            req.setSource(parts[2]);
            req.setOnboardNo(parts[3]);

            return req;
        }
    }
}
