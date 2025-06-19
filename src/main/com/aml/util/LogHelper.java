package main.com.aml.util;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;

public class LogHelper {
    private static final ObjectMapper mapper = new ObjectMapper();

    public static void logPrettyJson(Logger logger, String prefix, String json) {
        try {
            JsonNode jsonNode = mapper.readTree(json);
            String prettyJson = mapper.writerWithDefaultPrettyPrinter().writeValueAsString(jsonNode);
            logger.info("{}:\n{}", prefix, prettyJson);
        } catch (Exception e) {
            logger.warn("Failed to pretty print JSON. Logging raw string. Error: {}", e.getMessage());
            logger.info("{}: {}", prefix, json);
        }
    }

    public static void logValidationError(Logger logger, String fieldName, String message) {
        logger.error("Validation error on field '{}': {}", fieldName, message);
    }

    public static void logException(Logger logger, Exception e, String message) {
        logger.error(message, e);
    }
}
