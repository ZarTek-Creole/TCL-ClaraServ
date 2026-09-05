#!/usr/bin/env bash
# tools/test-local-process.sh — test process lifecycle sans IRCd / sans réseau.
# Ne valide ni S2S ni IRCServices sur un IRCd réel.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$ROOT/tests/harness_local_process.tcl"
TIMEOUT_START="${CLARASERV_TEST_START_TIMEOUT:-15}"
TIMEOUT_STOP="${CLARASERV_TEST_STOP_TIMEOUT:-15}"
TIMEOUT_TOTAL="${CLARASERV_TEST_TOTAL_TIMEOUT:-45}"

TMP=""
CHILD_PID=""
CLEANED=0

log() { printf '[test-local-process] %s\n' "$*"; }
die() { printf '[test-local-process] FAIL: %s\n' "$*" >&2; exit 1; }

cleanup() {
  local rc=$?
  if [[ "$CLEANED" -eq 1 ]]; then
    return 0
  fi
  CLEANED=1
  if [[ -n "${CHILD_PID}" ]] && kill -0 "$CHILD_PID" 2>/dev/null; then
    log "nettoyage: SIGTERM PID $CHILD_PID"
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    sleep 1
    if kill -0 "$CHILD_PID" 2>/dev/null; then
      log "nettoyage: SIGKILL PID $CHILD_PID"
      kill -KILL "$CHILD_PID" 2>/dev/null || true
    fi
    pkill -P "$CHILD_PID" 2>/dev/null || true
  fi
  if [[ -n "$TMP" && -d "$TMP" ]]; then
    rm -rf "$TMP"
  fi
  if [[ $rc -ne 0 ]]; then
    exit "$rc"
  fi
}
trap cleanup EXIT INT TERM

command -v tclsh >/dev/null 2>&1 || die "tclsh absent"
command -v timeout >/dev/null 2>&1 || die "timeout absent"
command -v mktemp >/dev/null 2>&1 || die "mktemp absent"
[[ -f "$HARNESS" ]] || die "harness introuvable: $HARNESS"
[[ -f "$ROOT/ClaraServ.tcl" ]] || die "ClaraServ.tcl introuvable"

PROD_RUN_BEFORE="$(find "$ROOT/run" -mindepth 1 ! -name '.gitkeep' 2>/dev/null | sort || true)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/claraserv-local-process.XXXXXX")"
RUNTIME="$TMP/run"
LOG="$TMP/process.log"
mkdir -p "$RUNTIME"

export CLARASERV_TEST_LOCAL_PROCESS=1
export CLARASERV_TEST_RUNTIME_DIR="$RUNTIME"

log "TMP=$TMP"
log "lancement harness (timeout total ${TIMEOUT_TOTAL}s)"

set +e
timeout --signal=TERM --kill-after=5 "${TIMEOUT_TOTAL}s" \
  tclsh "$HARNESS" >"$LOG" 2>&1 &
CHILD_PID=$!
set -e

ready_file="$RUNTIME/claraserv.ready"
pid_file="$RUNTIME/claraserv.pid"
stop_file="$RUNTIME/claraserv.stop"

deadline=$((SECONDS + TIMEOUT_START))
while (( SECONDS < deadline )); do
  if [[ -f "$ready_file" && -f "$pid_file" ]]; then
    break
  fi
  if ! kill -0 "$CHILD_PID" 2>/dev/null; then
    set +e
    wait "$CHILD_PID"
    set -e
    die "process mort avant readiness — logs:\n$(cat "$LOG" 2>/dev/null || true)"
  fi
  sleep 0.2
done

[[ -f "$ready_file" ]] || die "timeout readiness (${TIMEOUT_START}s) — logs:\n$(cat "$LOG" 2>/dev/null || true)"
[[ -f "$pid_file" ]] || die "pid file absent après readiness"
HARNESS_PID="$(tr -d '[:space:]' <"$pid_file")"
[[ "$HARNESS_PID" =~ ^[0-9]+$ ]] || die "PID invalide: $HARNESS_PID"
kill -0 "$HARNESS_PID" 2>/dev/null || die "PID harness mort: $HARNESS_PID"
log "ready OK (pid=$HARNESS_PID)"

PROD_RUN_MID="$(find "$ROOT/run" -mindepth 1 ! -name '.gitkeep' 2>/dev/null | sort || true)"
[[ "$PROD_RUN_BEFORE" == "$PROD_RUN_MID" ]] || die "fichiers créés sous $ROOT/run (production) pendant le test"

: >"$stop_file"
log "stop-file créé"

EXIT_CODE=""
deadline=$((SECONDS + TIMEOUT_STOP))
while (( SECONDS < deadline )); do
  if ! kill -0 "$CHILD_PID" 2>/dev/null; then
    set +e
    wait "$CHILD_PID"
    EXIT_CODE=$?
    set -e
    break
  fi
  sleep 0.2
done

if [[ -z "${EXIT_CODE}" ]]; then
  die "timeout attente arrêt (${TIMEOUT_STOP}s) — process encore vivant — logs:\n$(cat "$LOG" 2>/dev/null || true)"
fi

log "exit_code=$EXIT_CODE"
[[ "$EXIT_CODE" -eq 0 ]] || die "code de sortie attendu 0, obtenu $EXIT_CODE — logs:\n$(cat "$LOG")"

[[ ! -f "$stop_file" ]] || die "stop-file encore présent après shutdown (non consommé)"
[[ ! -f "$pid_file" ]] || die "pid file encore présent après shutdown"

if kill -0 "$HARNESS_PID" 2>/dev/null; then
  die "processus harness encore vivant ($HARNESS_PID)"
fi
if kill -0 "$CHILD_PID" 2>/dev/null; then
  die "wrapper timeout encore vivant ($CHILD_PID)"
fi
CHILD_PID=""

if grep -Eiq 'uplink_password|admin_password|password-connect|votre-mot-2-pass|mypassword' "$LOG"; then
  die "log contient un motif sensible interdit"
fi
grep -q 'TEST_LOCAL_PROCESS_READY' "$LOG" || die "log readiness manquant"
grep -Eqi 'Arrêt demandé \(stop-file\)' "$LOG" || die "log stop-file manquant"
if grep -q 'NETWORK_FORBIDDEN' "$LOG"; then
  die "tentative réseau détectée dans les logs"
fi

PROD_RUN_AFTER="$(find "$ROOT/run" -mindepth 1 ! -name '.gitkeep' 2>/dev/null | sort || true)"
[[ "$PROD_RUN_BEFORE" == "$PROD_RUN_AFTER" ]] || die "fuite de fichiers vers $ROOT/run"

log "PASS — lifecycle local-process (stop-file → exit 0), hors S2S/IRCd"
exit 0
