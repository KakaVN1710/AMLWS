#!/usr/bin/env bash
# Demo CALLJ T24 -> AmlClient -> Mock AML server
#   ./run-demo.sh            build + start mock + chay AML.CALLJ.DEMO + dung mock
#   ./run-demo.sh build      chi build
#   ./run-demo.sh mock       chay mock server (foreground)
#   ./run-demo.sh run <PROGRAM> [args...]   chay 1 routine jBC trong t24/BP (mock phai dang chay)
#   ./run-demo.sh package [AML_URL]          tao goi trien khai len T24 Model Bank that (build/t24-deploy)
#                                            AML_URL mac dinh http://localhost:8089 (URL mock nhin tu may T24)
#   MOCK_OPTS='-Dmock.watchlist.ids=100100' ./run-demo.sh mock   (tuy chon cho mock)
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
  exec java -Dmock.port="$MOCK_PORT" ${MOCK_OPTS:-} -cp "$MOCK_CP" demo.mock.MockAmlServer
}

# Goi trien khai cho TAFJ: jar (kem aml.properties tro toi mock), thu vien, token DB, routine
package_t24() {
  local url="${1:-http://localhost:8089}"
  local out="$BUILD/t24-deploy"
  build
  rm -rf "$out" "$BUILD/pkg-classes"
  mkdir -p "$out/lib/thirdparty" "$out/conf" "$out/data" "$out/BP" "$BUILD/pkg-classes"
  sed "s#^based.url=.*#based.url=$url#" "$DEMO_DIR/config/aml.properties" > "$out/conf/aml.properties"
  cp -r "$BUILD/aml-classes/." "$BUILD/pkg-classes/"
  cp "$out/conf/aml.properties" "$BUILD/pkg-classes/aml.properties"
  jar cf "$out/lib/aml-integration-full.jar" -C "$BUILD/pkg-classes" .
  cp "$BUILD/lib/callj-training.jar" "$out/lib/"
  for j in httpclient5-5.5 httpcore5-5.3.4 httpcore5-h2-5.3.4 jackson-core-2.15.0 jackson-databind-2.15.0 \
           jackson-annotations-2.15.0 sqlite-jdbc-3.50.1.0; do
    cp "$ROOT/libs/$j.jar" "$out/lib/thirdparty/"
  done
  cp "$TAFJ_HOME/data/AMLScan.db" "$out/data/"
  cp "$DEMO_DIR"/t24/BP/*.b "$out/BP/"
  for f in "$out"/BP/*.b; do mv "$f" "${f%.b}"; done      # TAFJ BP: ten file = ten routine
  echo ">> Goi trien khai: $out   (based.url=$url)"
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
  echo "Mock server khong khoi dong duoc" >&2; return 1
}

case "${1:-all}" in
  build) build ;;
  mock)  mock ;;
  run)   shift; run "$@" ;;
  package) shift; package_t24 "$@" ;;
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
  *) echo "Usage: $0 [all|build|mock|run <PROGRAM> [args...]|package [AML_URL]]"; exit 2 ;;
esac
