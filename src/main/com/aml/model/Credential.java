package main.com.aml.model;

public class Credential {
    private String key = "token";
    private String access_token;
    private String token_type;
    private long expires_in;
    private String userName;
    private String issued;
    private String expires;
    private String AccessToken;
    private String Expires;

    public String getAccessToken() {
        return AccessToken;
    }

    public void setAccessToken(String accessToken) {
        AccessToken = accessToken;
    }

    public Credential() {
        // Required by Jackson
    }
    public Credential(String key, String access_token, String token_type, long expires_in,
                      String userName, String issued, String expires) {
        this.key = "token";
        this.access_token = access_token;
        this.token_type = token_type;
        this.expires_in = expires_in;
        this.userName = userName;
        this.issued = issued;
        this.expires = expires;
    }

    // Getters and Setters
    public String getKey() { return key; }
    public void setKey(String key) {
        if (key == null || key.trim().isEmpty()) {
            this.key = "token"; //
        } else {
            this.key = key;
        }
    }

    public String getAccess_token() { return access_token; }
    public void setAccess_token(String access_token) { this.access_token = access_token; }

    public String getToken_type() { return token_type; }
    public void setToken_type(String token_type) { this.token_type = token_type; }

    public long getExpires_in() { return expires_in; }
    public void setExpires_in(long expires_in) { this.expires_in = expires_in; }

    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }

    public String getIssued() { return issued; }
    public void setIssued(String issued) { this.issued = issued; }

    public String getExpires() { return expires; }
    public void setExpires(String expires) { this.expires = expires; }
}
