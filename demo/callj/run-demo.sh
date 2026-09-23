#!/usr/bin/env bash
# Demo CALLJ T24 -> AmlClient -> Mock AML server
#   ./run-demo.sh            build + start mock + chay AML.CALLJ.DEMO + dung mock
#   ./run-demo.sh build      chi build
#   ./run-demo.sh mock       chay mock server (foreground)
#   ./run-demo.sh run <PROGRAM> [args...]   chay 1 routine jBC trong t24/BP (mock phai dang chay)
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
BUILD="$DEMO_DIR/build"
MOCK_PORT="${MOCK_PORT:-8089}"
export TAFJ_HOME="$BUILD/tafj_home"          # sqlite.db.path=%TAFJ_HOME%/data/AMLScan.db

LIBS="$ROOT/libs/*"
LIBMON="$ROOT/libMonitor/*"                 # TemnLogger/OpenTelemetry (co san trong TAFJ runtime)
# Classpath "T24/TAFJ": config (aml.properties) truoc, sau do cac jar CALLJ (tuong duong BNK_EJB/lib)
T24_CP="$DEMO_DIR/config:$BUILD/lib/aml-integration-full.jar:$BUILD/lib/callj-training.jar:$LIBS:$LIBMON:$BUILD/sim-classes"
MOCK_CP="$BUILD/mock-classes:$LIBS"

build() {
  echo ">> Build aml-integration-full.jar tu src/main (AmlClient)"
  rm -rf "$BUILD/aml-classes" "$BUILD/training-classes" "$BUILD/mock-classes" "$BUILD/sim-classes"
  rm -f "$TAFJ_HOME/data/AMLScan.db"          # xoa token cache cu
  mkdir -p "$BUILD/lib" "$TAFJ_HOME/data"
  javac -proc:none -encoding UTF-8 -nowarn -cp "$LIBS" -d "$BUILD/aml-classes" $(find "$ROOT/src/main" -name '*.java')
  jar cf "$BUILD/lib/aml-integration-full.jar" -C "$BUILD/aml-classes" .
  echo ">> Build callj-training.jar (com.temenos.training.HelloWorld)"
  javac -encoding UTF-8 -d "$BUILD/training-classes" $(find "$DEMO_DIR/java" -name '*.java')
  jar cf "$BUILD/lib/callj-training.jar" -C "$BUILD/training-classes" .
  echo ">> Build mock AML server"
  javac -proc:none -encoding UTF-8 -cp "$LIBS" -d "$BUILD/mock-classes" $(find "$DEMO_DIR/mock-server/src" -name '*.java')
  echo ">> Build T24 simulator (jBC runner + CALLJ)"
  javac -proc:none -encoding UTF-8 -cp "$LIBS" -d "$BUILD/sim-classes" $(find "$DEMO_DIR/t24-sim/src" -name '*.java')
  java -cp "$T24_CP" demo.t24.InitTokenDb
}

mock() {
  exec java -Dmock.port="$MOCK_PORT" -cp "$MOCK_CP" demo.mock.MockAmlServer
}

run() {
  java -cp "$T24_CP" demo.t24.JbcRunner --bp "$DEMO_DIR/t24/BP" "$@"
}

wait_port() {
  for _ in $(seq 1 50); do
    (echo > "/dev/tcp/127.0.0.1/$MOCK_PORT") 2>/dev/null && return 0
    sleep 0.2
  done
  echo "Mock server khong khoi dong duoc" >&2; return 1
}

case "${1:-all}" in
  build) build ;;
  mock)  mock ;;
  run)   shift; run "$@" ;;
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
  *) echo "Usage: $0 [all|build|mock|run <PROGRAM> [args...]]"; exit 2 ;;
esac
