package com.demo.kafka;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;

/**
 * Kafka producer for T24 CALLJ.
 *
 * <pre>
 *   CALLJ "com.demo.kafka.KafkaPublisher", "$publish", "topic@key@message" SETTING ret
 * </pre>
 *
 * Input : {@code topic@key@message} - split on the first two '@' only, so the message may contain '@'.
 *         Empty topic -> {@code demo.topic} from kafka.properties; empty key -> no key.
 * Output: {@code OK#topic#partition#offset#timestamp} once Kafka has acknowledged the record,
 *         or {@code ERROR#description}.
 *
 * Configuration: kafka.properties on the classpath. Every entry except "demo.*" is passed to the
 * producer (bootstrap.servers, acks, timeouts...). The producer is created once and reused by
 * every CALLJ in the JVM.
 */
public class KafkaPublisher {

    private static final Properties CONFIG = loadConfig();
    private static volatile KafkaProducer<String, String> producer;

    public static String publish(String input) {
        try {
            String[] parts = (input == null ? "" : input).split("@", 3);
            String topic = parts[0].trim().isEmpty() ? CONFIG.getProperty("demo.topic", "t24.callj.demo") : parts[0].trim();
            String key = parts.length > 1 && !parts[1].isEmpty() ? parts[1] : null;
            String value = parts.length > 2 ? parts[2] : "";

            ProducerRecord<String, String> record = new ProducerRecord<>(topic, key, value);
            record.headers().add("source", "T24-CALLJ".getBytes(StandardCharsets.UTF_8));

            long timeoutMs = Long.parseLong(CONFIG.getProperty("demo.send.timeout.ms", "10000"));
            RecordMetadata md = producer().send(record).get(timeoutMs, TimeUnit.MILLISECONDS);
            return String.join("#", "OK", md.topic(), String.valueOf(md.partition()),
                    String.valueOf(md.offset()), Instant.ofEpochMilli(md.timestamp()).toString());
        } catch (ExecutionException e) {
            return "ERROR#" + describe(e.getCause() != null ? e.getCause() : e);
        } catch (Exception e) {
            return "ERROR#" + describe(e);
        }
    }

    private static KafkaProducer<String, String> producer() {
        if (producer == null) {
            synchronized (KafkaPublisher.class) {
                if (producer == null) {
                    Properties props = new Properties();
                    CONFIG.stringPropertyNames().stream()
                            .filter(k -> !k.startsWith("demo."))
                            .forEach(k -> props.put(k, CONFIG.getProperty(k)));
                    props.putIfAbsent("client.id", "t24-callj");
                    props.putIfAbsent("acks", "all");
                    props.putIfAbsent("max.block.ms", "5000");
                    props.putIfAbsent("request.timeout.ms", "5000");
                    props.putIfAbsent("delivery.timeout.ms", "10000");
                    // Application servers (TAFJ) use their own context class loader; Kafka loads plugin
                    // classes through it, so create the producer with this class's loader and pass
                    // serializer instances instead of class names.
                    Thread t = Thread.currentThread();
                    ClassLoader previous = t.getContextClassLoader();
                    t.setContextClassLoader(KafkaPublisher.class.getClassLoader());
                    try {
                        producer = new KafkaProducer<>(props, new StringSerializer(), new StringSerializer());
                    } finally {
                        t.setContextClassLoader(previous);
                    }
                    Runtime.getRuntime().addShutdownHook(new Thread(() -> producer.close()));
                }
            }
        }
        return producer;
    }

    private static Properties loadConfig() {
        Properties p = new Properties();
        try (InputStream in = KafkaPublisher.class.getClassLoader().getResourceAsStream("kafka.properties")) {
            if (in != null) p.load(in);
        } catch (Exception ignored) {
            // defaults below
        }
        p.putIfAbsent("bootstrap.servers", "localhost:9092");
        return p;
    }

    private static String describe(Throwable e) {
        String msg = e.getClass().getSimpleName() + ": " + e.getMessage();
        return msg.replace('#', ' ').replace('\n', ' ');
    }

    /** Command-line test: java com.demo.kafka.KafkaPublisher "topic@key@message" */
    public static void main(String[] args) {
        System.out.println(publish(args.length > 0 ? args[0] : "@test@Hello Kafka from KafkaPublisher"));
        if (producer != null) producer.close();
    }
}
