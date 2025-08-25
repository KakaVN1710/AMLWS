package main.com.aml.model;

import com.fasterxml.jackson.databind.ObjectMapper;

public class RealTimeExposureResponse {
    public String ExposureInformation;

    public String getWatchlist_Match() {
        return Watchlist_Match;
    }

    public void setWatchlist_Match(String watchlist_Match) {
        Watchlist_Match = watchlist_Match;
    }

    public String getWatchlist_Match_Code() {
        return Watchlist_Match_Code;
    }

    public void setWatchlist_Match_Code(String watchlist_Match_Code) {
        Watchlist_Match_Code = watchlist_Match_Code;
    }

    public String getPEP_RCA_FM_Status_Code() {
        return PEP_RCA_FM_Status_Code;
    }

    public void setPEP_RCA_FM_Status_Code(String PEP_RCA_FM_Status_Code) {
        this.PEP_RCA_FM_Status_Code = PEP_RCA_FM_Status_Code;
    }

    public String Watchlist_Match;
    public String Watchlist_Match_Code;
    public String PEP_RCA_FM_Status;
    public String PEP_RCA_FM_Status_Code;
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
        return Watchlist_Match;
    }

    public void setWatchlistMatch(String watchlistMatch) {
        Watchlist_Match = watchlistMatch;
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
                nonNull(Watchlist_Match),
                nonNull(Watchlist_Match_Code),
                nonNull(PEP_RCA_FM_Status),
                nonNull(PEP_RCA_FM_Status_Code),
                nonNull(Handshake)
        );
    }

    private String nonNull(String value) {
        return value == null ? "" : value;
    }
}
