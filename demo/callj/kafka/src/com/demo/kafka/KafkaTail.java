package com.demo.kafka;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.header.Header;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

/**
 * Shows what Kafka has recorded: prints every record of a topic (from the beginning) and keeps
 * following new ones until Ctrl+C.
 *
 * Usage: java com.demo.kafka.KafkaTail [topic] [bootstrap.servers]
 */
public class KafkaTail {
    public static void main(String[] args) {
        String topic = args.length > 0 ? args[0] : "t24.callj.demo";
        String bootstrap = args.length > 1 ? args[1] : "localhost:9092";

        Properties props = new Properties();
        props.put("bootstrap.servers", bootstrap);
        props.put("group.id", "t24-callj-tail-" + UUID.randomUUID());
        props.put("auto.offset.reset", "earliest");
        props.put("enable.auto.commit", "false");

        System.out.println("Following topic '" + topic + "' on " + bootstrap + " (Ctrl+C to stop)");
        try (KafkaConsumer<String, String> consumer =
                     new KafkaConsumer<>(props, new StringDeserializer(), new StringDeserializer())) {
            consumer.subscribe(List.of(topic));
            while (true) {
                for (ConsumerRecord<String, String> r : consumer.poll(Duration.ofSeconds(1))) {
                    StringBuilder headers = new StringBuilder();
                    for (Header h : r.headers()) {
                        headers.append(h.key()).append('=').append(new String(h.value(), StandardCharsets.UTF_8)).append(' ');
                    }
                    System.out.printf("[%s] %s partition=%d offset=%d key=%s %s%n    %s%n",
                            Instant.ofEpochMilli(r.timestamp()), r.topic(), r.partition(), r.offset(),
                            r.key(), headers.toString().trim(), r.value());
                }
            }
        }
    }
}
