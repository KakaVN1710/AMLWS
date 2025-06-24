package main.com.aml.model;

import com.fasterxml.jackson.databind.ObjectMapper;

public class RealTimeExposureResponse {
    public String ExposureInformation;
    public String WatchlistMatch;
    public String PEP_RCA_FM_Status;
    public String Handshake;

    public static RealTimeExposureResponse fromJson(String json) throws Exception {
        return new ObjectMapper().readValue(json, RealTimeExposureResponse.class);
    }

    public String getExposureInformation() {
        return ExposureInformation;
    }

    public void setExposureInformation(String exposureInformation) {
        ExposureInformation = exposureInformation;
    }

    public String getWatchlistMatch() {
        return WatchlistMatch;
    }

    public void setWatchlistMatch(String watchlistMatch) {
        WatchlistMatch = watchlistMatch;
    }

    public String getPEP_RCA_FM_Status() {
        return PEP_RCA_FM_Status;
    }

    public void setPEP_RCA_FM_Status(String PEP_RCA_FM_Status) {
        this.PEP_RCA_FM_Status = PEP_RCA_FM_Status;
    }

    public String getHandshake() {
        return Handshake;
    }

    public void setHandshake(String handshake) {
        Handshake = handshake;
    }
    public String toDelimitedString() {
        return String.join("#",
                nonNull(ExposureInformation),
                nonNull(WatchlistMatch),
                nonNull(PEP_RCA_FM_Status),
                nonNull(Handshake)
        );
    }

    private String nonNull(String value) {
        return value == null ? "" : value;
    }
}
