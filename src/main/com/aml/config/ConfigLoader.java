package main.com.aml.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class ConfigLoader {
    private static final Properties props = new Properties();

    static {
        try (InputStream input = ConfigLoader.class.getClassLoader().getResourceAsStream("aml.properties")) {
            if (input == null) {
                throw new RuntimeException("aml.properties not found in classpath");
            }
            props.load(input);
        } catch (IOException e) {
            throw new RuntimeException("Failed to load aml.properties", e);
        }
    }

    public static String get(String key) {
        String raw = props.getProperty(key);
        if (raw == null) return null;

        // Resolve all %ENV_VAR% placeholders
        return resolveEnvVariables(raw);
    }

    private static String resolveEnvVariables(String value) {
        int start, end;
        while ((start = value.indexOf('%')) != -1 && (end = value.indexOf('%', start + 1)) != -1) {
            String envKey = value.substring(start + 1, end);
            String envValue = System.getenv(envKey);
            if (envValue == null) {
                return value;
            }
            value = value.substring(0, start) + envValue + value.substring(end + 1);
        }
        return value;
    }
}
