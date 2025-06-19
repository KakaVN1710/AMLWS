package main.com.aml.database;

import java.sql.*;

import main.com.aml.AppLogger;
import main.com.aml.config.ConfigLoader;
import main.com.aml.model.Credential;
import org.apache.logging.log4j.Logger;

public class CredentialDAO {
    private static final Logger logger = AppLogger.logger;
    private static String DB_URL = "jdbc:sqlite:AMLScan.db";
    public CredentialDAO(){
        String dbPath = ConfigLoader.get("sqlite.db.path");
        DB_URL = "jdbc:sqlite:" + dbPath;
    }

    public void saveCredential(Credential credential) {
        String sql = "INSERT INTO credential (key, access_token, token_type, expires_in, userName, issued, expires) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?) " +
                        "ON CONFLICT(key) DO UPDATE SET " +
                        "access_token = excluded.access_token, " +
                        "token_type = excluded.token_type, " +
                        "expires_in = excluded.expires_in, " +
                        "userName = excluded.userName, " +
                        "issued = excluded.issued, " +
                        "expires = excluded.expires";

        try (Connection conn = DriverManager.getConnection(DB_URL);
             PreparedStatement prepareStatement = conn.prepareStatement(sql)) {

            prepareStatement.setString(1, credential.getKey());
            prepareStatement.setString(2, credential.getAccess_token());
            prepareStatement.setString(3, credential.getToken_type());
            prepareStatement.setLong(4, credential.getExpires_in());
            prepareStatement.setString(5, credential.getUserName());
            prepareStatement.setString(6, credential.getIssued());
            prepareStatement.setString(7, credential.getExpires());

            prepareStatement.executeUpdate();
        } catch (SQLException e) {
            logger.error( "Failed to save credential: ", e);
        }
    }

    public Credential loadCredential(String key) {
        String sql = "SELECT * FROM credential WHERE key = ?";

        try (Connection conn = DriverManager.getConnection(DB_URL);
             PreparedStatement prepareStatement = conn.prepareStatement(sql)) {

            prepareStatement.setString(1, key);
            ResultSet rs = prepareStatement.executeQuery();

            if (rs.next()) {
                return new Credential(
                        rs.getString("key"),
                        rs.getString("access_token"),
                        rs.getString("token_type"),
                        rs.getLong("expires_in"),
                        rs.getString("userName"),
                        rs.getString("issued"),
                        rs.getString("expires")
                );
            }
        } catch (SQLException e) {
            logger.error( "Failed to load credential: ", e);
        }
        return null;
    }

    public void deleteCredential(String key) {
        String sql = "DELETE FROM credential WHERE key = ?";

        try (Connection conn = DriverManager.getConnection(DB_URL);
             PreparedStatement prepareStatement = conn.prepareStatement(sql)) {

            prepareStatement.setString(1, key);
            prepareStatement.executeUpdate();
        } catch (SQLException e) {
            logger.error( "Failed to delete credential: ", e);
        }
    }
}
