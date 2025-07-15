package main.com.aml;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.temenos.logging.facade.Logger;
import com.temenos.logging.facade.LoggerFactory;
import main.com.aml.config.ConfigLoader;
import main.com.aml.database.CredentialDAO;
import main.com.aml.model.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.hc.client5.http.classic.methods.HttpPost;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClients;
import org.apache.hc.core5.http.ContentType;
import org.apache.hc.core5.http.io.entity.StringEntity;
import org.apache.hc.core5.http.io.HttpClientResponseHandler;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;


public class AmlClient {
    private static final ObjectMapper mapper = new ObjectMapper();
    private static String cachedToken = null;
    private static long tokenExpiryTime = 0;
    private static final Logger logger = LoggerFactory.getLogger("AML");
    private static boolean exposureFlag = false;

    public static String getAccessToken() throws IOException {
        long currentTime = System.currentTimeMillis();

        if (cachedToken != null && currentTime < tokenExpiryTime) {
            logger.debug("Using cached token");
            return cachedToken;
        }

        Map<String, String> body = new HashMap<>();
        body.put("AuthID", ConfigLoader.get("auth.id"));
        body.put("AuthPW", ConfigLoader.get("auth.pw"));

        String fullUrl;
        if (exposureFlag) {
            fullUrl = ConfigLoader.get("based.url") + ConfigLoader.get("getTokenExposure.url");
        } else {
            fullUrl = ConfigLoader.get("based.url") + ConfigLoader.get("getToken.url");
        }

        HttpPost post = new HttpPost(fullUrl);
        post.setEntity(new StringEntity(mapper.writeValueAsString(body), ContentType.APPLICATION_JSON));

        try (CloseableHttpClient client = HttpClients.createDefault()) {
            JsonNode response = client.execute(post, httpResponse ->
                    mapper.readTree(httpResponse.getEntity().getContent())
            );
            int expiresIn;
            if (exposureFlag) {
                cachedToken = response.get("AccessToken").asText();
                expiresIn = response.get("Expires").asInt();
                tokenExpiryTime = currentTime + (expiresIn * 1000L);

            } else {
                cachedToken = response.get("access_token").asText();
                expiresIn = response.get("expires_in").asInt();
                tokenExpiryTime = currentTime + (expiresIn * 1000L);
            }


            logger.info("New token retrieved, expires in {}s", expiresIn);
            handleTokenResponse(response);
            return cachedToken;
        }
    }

    private static void handleTokenResponse(JsonNode response){
        try {
            if (response != null){
                Credential credential = mapper.treeToValue(response, Credential.class);
                long expireAt  = credential.getExpires_in();
                credential.setExpires_in(System.currentTimeMillis() + (expireAt * 1000L));
                CredentialDAO dao = new CredentialDAO();
                if (exposureFlag){
                    credential.setKey("tokenExposure");
                }
                dao.saveCredential(credential);
                logger.info("Saved new access token, expire at: {}", credential.getExpires());
            }
        } catch (JsonProcessingException exception){
            logger.error("Handle token response failed: {}", exception.getMessage(), exception);
        }
    }

    private static String getCachedToken() throws IOException {
        String token;
        CredentialDAO dao = new CredentialDAO();
        Credential credential;
        cachedToken = null;
        if (exposureFlag) {
            credential = dao.loadCredential("tokenExposure");
        } else {
            credential = dao.loadCredential("token");
        }

        if (credential == null) {
            logger.info("Not found credential in database");
            token = getAccessToken();
            return token;
        }
        if(System.currentTimeMillis() > credential.getExpires_in()){
            logger.info("Token expired at: {}, get a new token", credential.getExpires());
            token = getAccessToken();
        }
        else {
            token = credential.getAccess_token();
            cachedToken = token;
            tokenExpiryTime = credential.getExpires_in();
        }

        return token;
    }
    public static String callRealTimeScan(String params) {
        logger.info("Calling AML scan API...");

        try {
            RealTimeScanRequest request = RealTimeScanRequest.Builder.fromDelimitedString(params);

            String jsonRequest = mapper.writeValueAsString(request);
            logger.info("Request JSON:\n{}", mapper.writerWithDefaultPrettyPrinter().writeValueAsString(request));

            try (CloseableHttpClient client = HttpClients.createDefault()) {
                HttpPost post = new HttpPost(ConfigLoader.get("based.url") + ConfigLoader.get("realTimeScan.url"));
                post.setHeader("Content-Type", "application/json");
                exposureFlag = false;
                String token = getCachedToken();
                post.setHeader("Authorization", "Bearer " + token);
                post.setEntity(new StringEntity(jsonRequest, StandardCharsets.UTF_8));

                HttpClientResponseHandler<String> responseHandler = response -> {
                    int statusCode = response.getCode();
                    InputStream contentStream = response.getEntity().getContent();
                    String responseBody = new String(contentStream.readAllBytes(), StandardCharsets.UTF_8);

                    logger.info("HTTP response code: {}", statusCode);
                    try {
                        JsonNode jsonNode = mapper.readTree(responseBody);
                        String prettyJson = mapper.writerWithDefaultPrettyPrinter().writeValueAsString(jsonNode);
                        logger.info("Raw JSON Response:\n{}", prettyJson);
                    } catch (Exception ex) {
                        logger.warn("Response is not valid JSON:\n{}", responseBody);
                    }
                    try {
                        RealTimeScanResponse obj = mapper.readValue(responseBody, RealTimeScanResponse.class);
                        String delimited = obj.toDelimitedString();
                        logger.info("Parsed AML response: {}", delimited);
                        return delimited;
                    } catch (Exception ex) {
                        logger.warn("Response is not valid JSON or does not match expected fields. Raw body:\n{}", responseBody);
                        return responseBody;
                    }
                };

                return client.execute(post, responseHandler);
            }

        } catch (Exception e) {
            logger.error("AML scan error: {}", e.getMessage(), e);
            return "{\"error\": \"" + e.getMessage() + "\"}";
        }
    }
    public static String callRealTimeApprovalStatus(String params) {
        logger.info("Calling RealTimeApprovalStatus (Pull) API...");

        try {
            RealTimeApprovalStatusRequest request = RealTimeApprovalStatusRequest.Builder.fromDelimitedString(params);

            String jsonRequest = mapper.writeValueAsString(request);
            logger.info("Request JSON:\n{}", mapper.writerWithDefaultPrettyPrinter().writeValueAsString(request));

            try (CloseableHttpClient client = HttpClients.createDefault()) {
                HttpPost post = new HttpPost(ConfigLoader.get("based.url") + ConfigLoader.get("realTimeApprovalStatus.url"));
                post.setHeader("Content-Type", "application/json");
                exposureFlag = false;
                String token = getCachedToken();
                post.setHeader("Authorization", "Bearer " + token);
                post.setEntity(new StringEntity(jsonRequest, StandardCharsets.UTF_8));

                HttpClientResponseHandler<String> responseHandler = response -> {
                    int statusCode = response.getCode();
                    InputStream contentStream = response.getEntity().getContent();
                    String responseBody = new String(contentStream.readAllBytes(), StandardCharsets.UTF_8);

                    logger.info("HTTP response code: {}", statusCode);
                    try {
                        JsonNode jsonNode = mapper.readTree(responseBody);
                        String prettyJson = mapper.writerWithDefaultPrettyPrinter().writeValueAsString(jsonNode);
                        logger.info("Raw JSON Response:\n{}", prettyJson);
                    } catch (Exception ex) {
                        logger.warn("Response is not valid JSON:\n{}", responseBody);
                    }
                    try {
                        RealTimeApprovalStatusResponse obj = mapper.readValue(responseBody, RealTimeApprovalStatusResponse.class);
                        String delimited = obj.toDelimitedString();
                        logger.info("Parsed Approval Status response: {}", delimited);
                        return delimited;
                    } catch (Exception ex) {
                        logger.warn("Response is not valid JSON or does not match expected fields. Raw body:\n{}", responseBody);
                        return responseBody;
                    }
                };

                return client.execute(post, responseHandler);
            }

        } catch (Exception e) {
            logger.error("Approval status error: {}", e.getMessage(), e);
            return "{\"error\": \"" + e.getMessage() + "\"}";
        }
    }
    public static String callRealTimeExposure(String params) {
        logger.info("Calling RealTimeExposure (Pull) API...");
        exposureFlag = true;
        try {
            RealTimeExposureRequest request = RealTimeExposureRequest.Builder.fromDelimitedString(params);

            String jsonRequest = mapper.writeValueAsString(request);
            logger.info("Request JSON:\n{}", mapper.writerWithDefaultPrettyPrinter().writeValueAsString(request));

            try (CloseableHttpClient client = HttpClients.createDefault()) {
                HttpPost post = new HttpPost(ConfigLoader.get("based.url") + ConfigLoader.get("realTimeExposure.url"));
                post.setHeader("Content-Type", "application/json");
                String token = getCachedToken();
                post.setHeader("Authorization", "Bearer " + token);
                post.setEntity(new StringEntity(jsonRequest, StandardCharsets.UTF_8));

                HttpClientResponseHandler<String> responseHandler = response -> {
                    int statusCode = response.getCode();
                    InputStream contentStream = response.getEntity().getContent();
                    String responseBody = new String(contentStream.readAllBytes(), StandardCharsets.UTF_8);

                    logger.info("HTTP response code: {}", statusCode);
                    try {
                        JsonNode jsonNode = mapper.readTree(responseBody);
                        String prettyJson = mapper.writerWithDefaultPrettyPrinter().writeValueAsString(jsonNode);
                        logger.info("Raw JSON Response:\n{}", prettyJson);
                    } catch (Exception ex) {
                        logger.warn("Response is not valid JSON:\n{}", responseBody);
                    }
                    try {
                        RealTimeExposureResponse obj = mapper.readValue(responseBody, RealTimeExposureResponse.class);
                        String delimited = obj.toDelimitedString();
                        logger.info("Parsed Exposure response: {}", delimited);
                        return delimited;
                    } catch (Exception ex) {
                        logger.warn("Response is not valid JSON or does not match expected fields. Raw body:\n{}", responseBody);
                        return responseBody;
                    }
                };

                return client.execute(post, responseHandler);
            }

        } catch (Exception e) {
            logger.error("Exposure API error: {}", e.getMessage(), e);
            return "{\"error\": \"" + e.getMessage() + "\"}";
        }
    }
    public static void main(String[] args) {


        String realTimeScanResult = callRealTimeScan("SBI602640@KH0010001@CBS@1248551@1@Y@I@N@Heng Soka@US@2000@M@@12356789@@@@@2#KH|KH|02|0|0|1|0");
        System.out.println("✅ AML SCAN RESULT:");
        System.out.println(realTimeScanResult);

        // Test realTimeExposure
        String exposureResult = callRealTimeExposure("SBI602640@KH0010001@CBS@1248551");
        System.out.println("✅ AML EXPOSURE RESULT:");
        System.out.println(exposureResult);

        String approvalStatusResult = callRealTimeApprovalStatus("A001@PJ@AML@1248551@");
        System.out.println("✅ AML APPROVAL STATUS RESULT:");
        System.out.println(approvalStatusResult);
    }
}
