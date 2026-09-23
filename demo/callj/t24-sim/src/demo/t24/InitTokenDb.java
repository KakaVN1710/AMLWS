package demo.t24;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;

/**
 * Creates %TAFJ_HOME%/data/AMLScan.db with the "credential" table used by CredentialDAO
 * (token cache of AmlClient). Safe to run multiple times.
 */
public class InitTokenDb {
    public static void main(String[] args) throws Exception {
        String home = System.getenv("TAFJ_HOME");
        if (home == null || home.isBlank()) throw new IllegalStateException("TAFJ_HOME is not set");
        Path db = Paths.get(home, "data", "AMLScan.db");
        Files.createDirectories(db.getParent());
        try (Connection c = DriverManager.getConnection("jdbc:sqlite:" + db);
             Statement st = c.createStatement()) {
            st.executeUpdate("CREATE TABLE IF NOT EXISTS credential ("
                    + "key TEXT NOT NULL PRIMARY KEY, access_token TEXT NOT NULL, token_type TEXT, "
                    + "expires_in INTEGER NOT NULL, userName TEXT, issued TEXT, expires TEXT)");
        }
        System.out.println("Token DB ready: " + db);
    }
}
