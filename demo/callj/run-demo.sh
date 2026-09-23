#!/usr/bin/env bash
# Demo CALLJ T24 -> AmlClient -> Mock AML server
#   ./run-demo.sh            build + start mock + run AML.CALLJ.DEMO + stop mock
#   ./run-demo.sh build      build only
#   ./run-demo.sh mock       run the mock server (foreground)
#   ./run-demo.sh run <PROGRAM> [args...]   run one jBC routine from t24/BP (mock must be running)
#   ./run-demo.sh package [AML_URL] [KAFKA_BOOTSTRAP]
#                                            build the deployment package for a real T24 Model Bank (build/t24-deploy)
#                                            AML_URL defaults to http://localhost:8089 (mock URL as seen from the T24 server)
#                                            KAFKA_BOOTSTRAP defaults to localhost:9092 (Kafka as seen from the T24 server)
#   ./run-demo.sh kafka-up | kafka-down      start / stop Kafka + Kafka UI (docker compose, kafka/docker-compose.yml)
#   ./run-demo.sh kafka-tail [topic] [bootstrap]   show what Kafka recorded (default topic t24.callj.demo)
#   MOCK_OPTS='-Dmock.watchlist.ids=100100' ./run-demo.sh mock   (mock options)
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
BUILD="$DEMO_DIR/build"
MOCK_PORT="${MOCK_PORT:-8089}"
export TAFJ_HOME="$BUILD/tafj_home"          # sqlite.db.path=%TAFJ_HOME%/data/AMLScan.db

LIBS="$ROOT/libs/*"
KAFKA_LIB="$DEMO_DIR/kafka/lib/*"            # kafka-clients
LIBMON="$ROOT/libMonitor/*"                 # TemnLogger/OpenTelemetry (already part of the TAFJ runtime)
# "T24/TAFJ" classpath: config (aml.properties) first, then the CALLJ jars (like BNK_EJB/lib)
T24_CP="$DEMO_DIR/config:$BUILD/lib/aml-integration-full.jar:$BUILD/lib/callj-training.jar:$BUILD/lib/callj-kafka.jar:$KAFKA_LIB:$LIBS:$LIBMON:$BUILD/sim-classes"
MOCK_CP="$BUILD/mock-classes:$LIBS"

build() {
  echo ">> Build aml-integration-full.jar from src/main (AmlClient)"
  rm -rf "$BUILD/aml-classes" "$BUILD/training-classes" "$BUILD/mock-classes" "$BUILD/sim-classes"
  rm -f "$TAFJ_HOME/data/AMLScan.db"          # drop the old token cache
  mkdir -p "$BUILD/lib" "$TAFJ_HOME/data"
  javac -proc:none -encoding UTF-8 -nowarn -cp "$LIBS" -d "$BUILD/aml-classes" $(find "$ROOT/src/main" -name '*.java')
  jar cf "$BUILD/lib/aml-integration-full.jar" -C "$BUILD/aml-classes" .
  echo ">> Build callj-training.jar (com.temenos.training.HelloWorld)"
  javac -encoding UTF-8 -d "$BUILD/training-classes" $(find "$DEMO_DIR/java" -name '*.java')
  jar cf "$BUILD/lib/callj-training.jar" -C "$BUILD/training-classes" .
  echo ">> Build callj-kafka.jar (com.demo.kafka.KafkaPublisher / KafkaTail)"
  rm -rf "$BUILD/kafka-classes"
  javac -proc:none -encoding UTF-8 -cp "$KAFKA_LIB:$LIBS" -d "$BUILD/kafka-classes" $(find "$DEMO_DIR/kafka/src" -name '*.java')
  jar cf "$BUILD/lib/callj-kafka.jar" -C "$BUILD/kafka-classes" .
  echo ">> Build mock AML server"
  javac -proc:none -encoding UTF-8 -cp "$LIBS" -d "$BUILD/mock-classes" $(find "$DEMO_DIR/mock-server/src" -name '*.java')
  echo ">> Build T24 simulator (jBC runner + CALLJ)"
  javac -proc:none -encoding UTF-8 -cp "$LIBS" -d "$BUILD/sim-classes" $(find "$DEMO_DIR/t24-sim/src" -name '*.java')
  java -cp "$T24_CP" demo.t24.InitTokenDb
}

mock() {
  exec java -Dmock.port="$MOCK_PORT" ${MOCK_OPTS:-} -cp "$MOCK_CP" demo.mock.MockAmlServer
}

# TAFJ deployment package: jar (with aml.properties pointing to the mock), libraries, token DB, routines
package_t24() {
  local url="${1:-http://localhost:8089}"
  local kafka="${2:-localhost:9092}"
  local out="$BUILD/t24-deploy"
  build
  rm -rf "$out" "$BUILD/pkg-classes"
  mkdir -p "$out/lib/thirdparty" "$out/conf" "$out/data" "$out/BP" "$BUILD/pkg-classes"
  sed "s#^based.url=.*#based.url=$url#" "$DEMO_DIR/config/aml.properties" > "$out/conf/aml.properties"
  cp -r "$BUILD/aml-classes/." "$BUILD/pkg-classes/"
  cp "$out/conf/aml.properties" "$BUILD/pkg-classes/aml.properties"
  jar cf "$out/lib/aml-integration-full.jar" -C "$BUILD/pkg-classes" .
  cp "$BUILD/lib/callj-training.jar" "$out/lib/"
  sed "s#^bootstrap.servers=.*#bootstrap.servers=$kafka#" "$DEMO_DIR/config/kafka.properties" > "$out/conf/kafka.properties"
  rm -rf "$BUILD/pkg-kafka" && mkdir -p "$BUILD/pkg-kafka" && cp -r "$BUILD/kafka-classes/." "$BUILD/pkg-kafka/"
  cp "$out/conf/kafka.properties" "$BUILD/pkg-kafka/kafka.properties"
  jar cf "$out/lib/callj-kafka.jar" -C "$BUILD/pkg-kafka" .
  cp "$DEMO_DIR"/kafka/lib/*.jar "$out/lib/thirdparty/"
  for j in httpclient5-5.5 httpcore5-5.3.4 httpcore5-h2-5.3.4 jackson-core-2.15.0 jackson-databind-2.15.0 \
           jackson-annotations-2.15.0 sqlite-jdbc-3.50.1.0; do
    cp "$ROOT/libs/$j.jar" "$out/lib/thirdparty/"
  done
  cp "$TAFJ_HOME/data/AMLScan.db" "$out/data/"
  cp "$DEMO_DIR"/t24/BP/*.b "$out/BP/"
  for f in "$out"/BP/*.b; do mv "$f" "${f%.b}"; done      # TAFJ BP: file name = routine name
  cat > "$out/run-mb-demo.bat" <<'BAT'
@echo off
REM Run the Model Bank demo on TAFJ:  run-mb-demo.bat [CUSTOMER.ID ...]
REM OFS_SOURCE = id of an existing OFS.SOURCE record (see: tRun LIST F.OFS.SOURCE)
if "%OFS_SOURCE%"=="" set OFS_SOURCE=OFSONLINE
echo OFS_SOURCE=%OFS_SOURCE%
call tRun AML.CALLJ.MB.DEMO %*
BAT
  echo ">> Deployment package: $out   (based.url=$url, bootstrap.servers=$kafka)"
  (cd "$out" && find . -type f | sort)
}

run() {
  java -cp "$T24_CP" demo.t24.JbcRunner --bp "$DEMO_DIR/t24/BP" "$@"
}

wait_port() {
  for _ in $(seq 1 50); do
    (echo > "/dev/tcp/127.0.0.1/$MOCK_PORT") 2>/dev/null && return 0
    sleep 0.2
  done
  echo "Mock server did not start" >&2; return 1
}

case "${1:-all}" in
  build) build ;;
  mock)  mock ;;
  run)   shift; run "$@" ;;
  package) shift; package_t24 "$@" ;;
  kafka-up)   docker compose -f "$DEMO_DIR/kafka/docker-compose.yml" up -d ;;
  kafka-down) docker compose -f "$DEMO_DIR/kafka/docker-compose.yml" down ;;
  kafka-tail) shift; java -cp "$BUILD/lib/callj-kafka.jar:$KAFKA_LIB:$LIBS" com.demo.kafka.KafkaTail "$@" ;;
  all)
    build
    java -Dmock.port="$MOCK_PORT" -cp "$MOCK_CP" demo.mock.MockAmlServer > "$BUILD/mock-server.log" 2>&1 &
    MOCK_PID=$!
    trap 'kill $MOCK_PID 2>/dev/null || true' EXIT
    wait_port
    echo
    run CALLJ.HELLO
    echo
    run AML.CALLJ.DEMO
    echo
    echo ">> Log mock server: $BUILD/mock-server.log"
    ;;
  *) echo "Usage: $0 [all|build|mock|run <PROGRAM> [args...]|package [AML_URL] [KAFKA_BOOTSTRAP]|kafka-up|kafka-down|kafka-tail [topic]]"; exit 2 ;;
esac
