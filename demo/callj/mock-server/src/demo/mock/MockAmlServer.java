package demo.mock;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * Mock AML Web Service (AMLWS + AMLWS_EXPOSURE) used to demo CALLJ from T24.
 *
 * Endpoints (same paths as aml.properties):
 *   POST /AMLWS/api/GetToken               -> {access_token, token_type, expires_in, ...}
 *   POST /AMLWS_EXPOSURE/api/GetToken      -> {AccessToken, Expires, ...}
 *   POST /AMLWS/api/RealtimeScan           -> RealTimeScanResponse
 *   POST /AMLWS/api/RealTimeApproval       -> RealTimeApprovalStatusResponse
 *   POST /AMLWS_EXPOSURE/api/RealTimeExposure -> RealTimeExposureResponse
 *
 * Demo helpers:
 *   GET  /mock/approve?onboardNo=1001&status=A   (A=Approved, R=Rejected, P=Pending)
 *   GET  /mock/state                              (dump onboard cases + watchlist)
 *   GET  /mock/watchlist?addName=ROBERT SMITH     (add a name to the watchlist during the demo)
 *   GET  /mock/watchlist?addId=100100             (add a CUSTOMER id - matched on ClientNo/ReferenceNo)
 *   GET  /mock/watchlist?removeName=...&removeId=...
 *   Preload: -Dmock.watchlist="NAME 1,NAME 2" -Dmock.watchlist.ids=100100,100200
 *
 * Scan rules (evaluated on the request):
 *   - ClientID in WHITELIST                         -> WhitelistStatus=T, no hit
 *   - ClientName in WATCHLIST or ClientNo/ReferenceNo in watchlist ids
 *                                                   -> MatchStatus=T, RiskStatus=H, new OnboardNo
 *   - ClientCountry in SANCTION_COUNTRIES           -> SanctionCountryStatus=T, RiskStatus=H, new OnboardNo
 *   - ClientName in ADVERSE_MEDIA                   -> AdvMediaStatus=T, EDDStatus=T, RiskStatus=M, new OnboardNo
 *   - ClientName = "SERVER ERROR"                   -> HTTP 500
 *   - otherwise                                     -> clean (F#F#0####F####)
 */
public class MockAmlServer {

    private static final ObjectMapper mapper = new ObjectMapper();
    private static final DateTimeFormatter TS = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final Set<String> watchlist = ConcurrentHashMap.newKeySet();
    private final Set<String> watchlistIds = ConcurrentHashMap.newKeySet();
    private static final Set<String> ADVERSE_MEDIA = Set.of("TRAN THI B");
    private static final Set<String> SANCTION_COUNTRIES = Set.of("KP", "IR", "SY", "CU");
    private static final Set<String> WHITELIST = Set.of("WL000001");

    private static final int TOKEN_TTL_SECONDS = 300;

    private final String authId;
    private final String authPw;
    private final Map<String, ObjectNode> onboardCases = new ConcurrentHashMap<>();
    private final AtomicInteger onboardSeq = new AtomicInteger(1000);

    public MockAmlServer(String authId, String authPw) {
        this.authId = authId;
        this.authPw = authPw;
        watchlist.addAll(List.of("NGUYEN VAN A", "OSAMA BIN LADEN", "JOHN DOE SANCTIONED", "SOLOMON DAVID"));
        watchlistIds.add("10000083");                   // Model Bank customer Solomon David (AML.CALLJ.MB.DEMO.HIT)
        for (String n : System.getProperty("mock.watchlist", "").split(",")) {
            if (!n.isBlank()) watchlist.add(n.trim().toUpperCase(Locale.ROOT));
        }
        for (String id : System.getProperty("mock.watchlist.ids", "").split(",")) {
            if (!id.isBlank()) watchlistIds.add(id.trim());
        }
    }

    public static void main(String[] args) throws IOException {
        int port = Integer.parseInt(System.getProperty("mock.port", "8089"));
        String authId = System.getProperty("mock.auth.id", "t24");
        String authPw = System.getProperty("mock.auth.pw", "demo@123");
        new MockAmlServer(authId, authPw).start(port);
    }

    public void start(int port) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/AMLWS/api/GetToken", ex -> handle(ex, this::getToken));
        server.createContext("/AMLWS_EXPOSURE/api/GetToken", ex -> handle(ex, this::getTokenExposure));
        server.createContext("/AMLWS/api/RealtimeScan", ex -> handle(ex, this::realTimeScan));
        server.createContext("/AMLWS/api/RealTimeApproval", ex -> handle(ex, this::realTimeApproval));
        server.createContext("/AMLWS_EXPOSURE/api/RealTimeExposure", ex -> handle(ex, this::realTimeExposure));
        server.createContext("/mock/approve", ex -> handle(ex, this::mockApprove));
        server.createContext("/mock/state", ex -> handle(ex, this::mockState));
        server.createContext("/mock/watchlist", ex -> handle(ex, this::mockWatchlist));
        server.start();
        log("Mock AML server listening on http://localhost:" + port + " (all interfaces)");
        try {
            for (var ni : java.util.Collections.list(java.net.NetworkInterface.getNetworkInterfaces())) {
                if (!ni.isUp() || ni.isLoopback()) continue;
                for (var addr : java.util.Collections.list(ni.getInetAddresses())) {
                    if (addr instanceof java.net.Inet4Address) log("  reachable from T24 server as http://" + addr.getHostAddress() + ":" + port);
                }
            }
        } catch (Exception ignored) {
            // informational only
        }
        log("Auth: AuthID=" + authId + " (password from -Dmock.auth.pw)");
        log("Watchlist names=" + watchlist + " ids=" + watchlistIds);
    }

    // ------------------------------------------------------------------ handlers

    private Reply getToken(HttpExchange ex, JsonNode body) {
        if (!checkCredential(body)) {
            return new Reply(401, error("Invalid AuthID/AuthPW"));
        }
        String token = newToken("AMLWS");
        ObjectNode res = mapper.createObjectNode();
        res.put("access_token", token);
        res.put("token_type", "bearer");
        res.put("expires_in", TOKEN_TTL_SECONDS);
        res.put("userName", authId);
        res.put("issued", nowTs());
        res.put("expires", LocalDateTime.now().plusSeconds(TOKEN_TTL_SECONDS).format(TS));
        return new Reply(200, res);
    }

    private Reply getTokenExposure(HttpExchange ex, JsonNode body) {
        if (!checkCredential(body)) {
            return new Reply(401, error("Invalid AuthID/AuthPW"));
        }
        String token = newToken("EXPOSURE");
        ObjectNode res = mapper.createObjectNode();
        res.put("AccessToken", token);
        res.put("Expires", TOKEN_TTL_SECONDS);
        res.put("expires_in", TOKEN_TTL_SECONDS);
        res.put("userName", authId);
        res.put("issued", nowTs());
        res.put("expires", LocalDateTime.now().plusSeconds(TOKEN_TTL_SECONDS).format(TS));
        return new Reply(200, res);
    }

    private Reply realTimeScan(HttpExchange ex, JsonNode req) {
        if (!checkBearer(ex)) return new Reply(401, error("Authorization has been denied for this request."));

        String name = text(req, "ClientName").trim().toUpperCase(Locale.ROOT);
        String country = text(req, "ClientCountry").trim().toUpperCase(Locale.ROOT);
        String clientId = text(req, "ClientID").trim();
        boolean idListed = watchlistIds.contains(text(req, "ClientNo").trim())
                || watchlistIds.contains(text(req, "ReferenceNo").trim());

        if ("SERVER ERROR".equals(name)) {
            return new Reply(500, error("Simulated internal server error"));
        }

        ObjectNode res = mapper.createObjectNode();
        res.put("MatchStatus", "F");
        res.put("WhitelistStatus", "F");
        res.put("OnboardNo", 0);
        res.put("MatchURL", "");
        res.put("SanctionCountryStatus", "F");

        if (WHITELIST.contains(clientId)) {
            res.put("WhitelistStatus", "T");
            res.put("RiskStatus", "L");
            return new Reply(200, res);
        }

        boolean hit = false;
        if (watchlist.contains(name) || idListed) {
            hit = true;
            res.put("MatchStatus", "T");
            res.put("RiskStatus", "H");
        }
        if (SANCTION_COUNTRIES.contains(country)) {
            hit = true;
            res.put("SanctionCountryStatus", "T");
            res.put("RiskStatus", "H");
        }
        if (ADVERSE_MEDIA.contains(name)) {
            hit = true;
            res.put("AdvMediaStatus", "T");
            res.put("EDDStatus", "T");
            if (!res.has("RiskStatus")) res.put("RiskStatus", "M");
        }

        if (hit) {
            String onboardNo = String.valueOf(onboardSeq.incrementAndGet());
            res.put("OnboardNo", Integer.parseInt(onboardNo));
            res.put("PassportStatus", text(req, "PassportNo").isEmpty() ? "" : "F");
            if ("T".equals(res.path("MatchStatus").asText())) {
                res.put("MatchURL", "http://localhost/AMLWS/match/" + onboardNo);
            }
            if ("T".equals(res.path("EDDStatus").asText())) {
                res.put("EDDURL", "http://localhost/AMLWS/edd/" + onboardNo);
                res.put("AdvMediaURL", "http://localhost/AMLWS/media/" + onboardNo);
            }
            ObjectNode c = mapper.createObjectNode();
            c.put("OnboardNo", onboardNo);
            c.put("ReferenceNo", text(req, "ReferenceNo"));
            c.put("ClientName", text(req, "ClientName"));
            c.put("ClientCountry", country);
            c.put("RiskStatus", res.path("RiskStatus").asText());
            c.put("Watchlist", res.path("MatchStatus").asText());
            c.put("ApprovalStatus", "P");
            onboardCases.put(onboardNo, c);
            log("  -> HIT, created onboard case " + onboardNo + " (pending compliance approval)");
        }
        return new Reply(200, res);
    }

    private Reply realTimeApproval(HttpExchange ex, JsonNode req) {
        if (!checkBearer(ex)) return new Reply(401, error("Authorization has been denied for this request."));
        String onboardNo = text(req, "OnboardNo");
        ObjectNode res = mapper.createObjectNode();
        ObjectNode c = findCase(onboardNo, text(req, "ReferenceNo"));
        res.put("ApprovalStatus", c == null ? "N" : c.path("ApprovalStatus").asText());
        res.put("HandShake", c == null ? "N" : "Y");
        return new Reply(200, res);
    }

    private Reply realTimeExposure(HttpExchange ex, JsonNode req) {
        if (!checkBearer(ex)) return new Reply(401, error("Authorization has been denied for this request."));
        ObjectNode c = findCase(text(req, "OnboardNo"), text(req, "OnboardNo"));
        ObjectNode res = mapper.createObjectNode();
        if (c == null) {
            res.put("ExposureInformation", "No exposure");
            res.put("Watchlist_Match", "N");
            res.put("Watchlist_Match_Code", "");
            res.put("PEP_RCA_FM_Status", "N");
            res.put("PEP_RCA_FM_Status_Code", "");
        } else {
            boolean wl = "T".equals(c.path("Watchlist").asText());
            res.put("ExposureInformation", "Risk " + c.path("RiskStatus").asText() + " - " + c.path("ClientName").asText());
            res.put("Watchlist_Match", wl ? "Y" : "N");
            res.put("Watchlist_Match_Code", wl ? "WL01" : "");
            res.put("PEP_RCA_FM_Status", wl ? "PEP" : "N");
            res.put("PEP_RCA_FM_Status_Code", wl ? "P01" : "");
        }
        res.put("Handshake", "Y");
        return new Reply(200, res);
    }

    private Reply mockApprove(HttpExchange ex, JsonNode ignored) {
        Map<String, String> q = query(ex);
        String onboardNo = q.getOrDefault("onboardNo", "");
        String status = q.getOrDefault("status", "A");
        ObjectNode c = onboardCases.get(onboardNo);
        if (c == null) return new Reply(404, error("OnboardNo not found: " + onboardNo));
        c.put("ApprovalStatus", status);
        log("  -> Compliance set onboard " + onboardNo + " = " + status);
        return new Reply(200, c);
    }

    private Reply mockState(HttpExchange ex, JsonNode ignored) {
        ObjectNode res = mapper.createObjectNode();
        ObjectNode cases = res.putObject("onboardCases");
        onboardCases.forEach(cases::set);
        res.set("watchlist", mapper.valueToTree(new TreeSet<>(watchlist)));
        res.set("watchlistIds", mapper.valueToTree(new TreeSet<>(watchlistIds)));
        return new Reply(200, res);
    }

    private Reply mockWatchlist(HttpExchange ex, JsonNode ignored) {
        Map<String, String> q = query(ex);
        if (q.containsKey("addName")) watchlist.add(q.get("addName").trim().toUpperCase(Locale.ROOT));
        if (q.containsKey("removeName")) watchlist.remove(q.get("removeName").trim().toUpperCase(Locale.ROOT));
        if (q.containsKey("addId")) watchlistIds.add(q.get("addId").trim());
        if (q.containsKey("removeId")) watchlistIds.remove(q.get("removeId").trim());
        log("  -> Watchlist names=" + watchlist + " ids=" + watchlistIds);
        ObjectNode res = mapper.createObjectNode();
        res.set("watchlist", mapper.valueToTree(new TreeSet<>(watchlist)));
        res.set("watchlistIds", mapper.valueToTree(new TreeSet<>(watchlistIds)));
        return new Reply(200, res);
    }

    // ------------------------------------------------------------------ helpers

    private ObjectNode findCase(String onboardNo, String referenceNo) {
        if (onboardNo != null && onboardCases.containsKey(onboardNo)) return onboardCases.get(onboardNo);
        for (ObjectNode c : onboardCases.values()) {
            if (!referenceNo.isEmpty() && referenceNo.equals(c.path("ReferenceNo").asText())) return c;
        }
        return null;
    }

    private boolean checkCredential(JsonNode body) {
        return authId.equals(text(body, "AuthID")) && authPw.equals(text(body, "AuthPW"));
    }

    private boolean checkBearer(HttpExchange ex) {
        String auth = ex.getRequestHeaders().getFirst("Authorization");
        if (auth == null || !auth.startsWith("Bearer ")) return false;
        // token = <prefix>.<expiryEpochSec>.<hmac>  (stateless: still valid after a mock restart)
        String[] p = auth.substring(7).split("\\.");
        if (p.length != 3) return false;
        try {
            return sign(p[0] + "." + p[1]).equals(p[2]) && Long.parseLong(p[1]) > System.currentTimeMillis() / 1000;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    private String newToken(String prefix) {
        String payload = prefix + "." + (System.currentTimeMillis() / 1000 + TOKEN_TTL_SECONDS);
        return payload + "." + sign(payload);
    }

    private String sign(String payload) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec((authId + ":" + authPw).getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node == null ? null : node.get(field);
        return v == null || v.isNull() ? "" : v.asText();
    }

    private static ObjectNode error(String message) {
        ObjectNode n = mapper.createObjectNode();
        n.put("Message", message);
        return n;
    }

    private static Map<String, String> query(HttpExchange ex) {
        Map<String, String> m = new HashMap<>();
        String q = ex.getRequestURI().getRawQuery();
        if (q == null) return m;
        for (String p : q.split("&")) {
            String[] kv = p.split("=", 2);
            m.put(URLDecoder.decode(kv[0], StandardCharsets.UTF_8),
                    kv.length > 1 ? URLDecoder.decode(kv[1], StandardCharsets.UTF_8) : "");
        }
        return m;
    }

    private static String nowTs() {
        return LocalDateTime.now().format(TS);
    }

    private static void log(String msg) {
        System.out.println("[" + nowTs() + "] " + msg);
    }

    private interface Handler {
        Reply apply(HttpExchange ex, JsonNode body) throws IOException;
    }

    private record Reply(int status, JsonNode body) {}

    private void handle(HttpExchange ex, Handler handler) throws IOException {
        try {
            byte[] raw = ex.getRequestBody().readAllBytes();
            String bodyText = new String(raw, StandardCharsets.UTF_8);
            JsonNode body = bodyText.isBlank() ? mapper.createObjectNode() : mapper.readTree(bodyText);
            log(ex.getRequestMethod() + " " + ex.getRequestURI() + (bodyText.isBlank() ? "" : " " + mask(body)));
            Reply reply = handler.apply(ex, body);
            byte[] out = mapper.writeValueAsBytes(reply.body());
            log("  <- " + reply.status() + " " + reply.body());
            ex.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
            ex.sendResponseHeaders(reply.status(), out.length);
            try (OutputStream os = ex.getResponseBody()) {
                os.write(out);
            }
        } catch (Exception e) {
            byte[] out = mapper.writeValueAsBytes(error(e.toString()));
            ex.sendResponseHeaders(400, out.length);
            try (OutputStream os = ex.getResponseBody()) {
                os.write(out);
            }
        } finally {
            ex.close();
        }
    }

    private static String mask(JsonNode body) {
        if (body.has("AuthPW")) {
            ObjectNode copy = body.deepCopy();
            copy.put("AuthPW", "******");
            return copy.toString();
        }
        return body.toString();
    }
}
