package main.com.aml.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class RealTimeScanResponse {
    @JsonProperty("MatchStatus")
    private String matchStatus;

    @JsonProperty("WhitelistStatus")
    private String whitelistStatus;

    @JsonProperty("OnboardNo")
    private String onboardNo;

    @JsonProperty("MatchURL")
    private String matchURL;

    @JsonProperty("RiskStatus")
    private String riskStatus;

    @JsonProperty("PassportStatus")
    private String passportStatus;

    @JsonProperty("SanctionCountryStatus")
    private String sanctionCountryStatus;

    @JsonProperty("EDDStatus")
    private String eddStatus;

    @JsonProperty("EDDURL")
    private String eddURL;

    @JsonProperty("AdvMediaStatus")
    private String advMediaStatus;

    @JsonProperty("AdvMediaURL")
    private String advMediaURL;

    public String toDelimitedString() {
        return String.join("#",
                nonNull(matchStatus),
                nonNull(whitelistStatus),
                nonNull(onboardNo),
                nonNull(matchURL),
                nonNull(riskStatus),
                nonNull(passportStatus),
                nonNull(sanctionCountryStatus),
                nonNull(eddStatus),
                nonNull(eddURL),
                nonNull(advMediaStatus),
                nonNull(advMediaURL)
        );
    }

    private String nonNull(String value) {
        return value == null ? "" : value;
    }
}
