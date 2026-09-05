#!/usr/bin/env bash
# Enveloppe healthcheck ClaraServ — Bash + Tcl, sans réseau.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: tools/healthcheck.sh [--help]

Enchaîne:
  1. contrôles Bash (bash -n, shellcheck si présent)
  2. tools/healthcheck.tcl (statique, sans connexion IRC)

Codes: 0=OK, 1=échec, 2=usage
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

PASS=0
WARN=0
FAIL=0
ok()   { printf '[PASS] %s\n' "$*"; PASS=$((PASS + 1)); }
warn() { printf '[WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
fail() { printf '[FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }

echo "ClaraServ healthcheck.sh"
echo "Racine: $ROOT"
echo "------------------------------------------------------------"

if ! command -v tclsh >/dev/null 2>&1; then
  fail "tclsh absent"
  echo "Résumé: PASS=$PASS WARN=$WARN FAIL=$FAIL"
  exit 1
fi
ok "tclsh disponible"

SHELL_SCRIPTS=(
  tools/bootstrap-dev.sh
  tools/healthcheck.sh
  tools/test-local-process.sh
  tools/test-claraserv-screen.sh
  bin/claraserv-screen
)
for s in "${SHELL_SCRIPTS[@]}"; do
  if [[ -f "$ROOT/$s" ]]; then
    if bash -n "$ROOT/$s"; then
      ok "bash -n $s"
    else
      fail "bash -n $s"
    fi
    if command -v shellcheck >/dev/null 2>&1; then
      if shellcheck -x "$ROOT/$s"; then
        ok "shellcheck $s"
      else
        warn "shellcheck $s a signalé des problèmes"
      fi
    fi
  else
    warn "script absent: $s"
  fi
done

if [[ ! -f "$ROOT/tools/healthcheck.tcl" ]]; then
  fail "tools/healthcheck.tcl manquant"
  echo "Résumé: PASS=$PASS WARN=$WARN FAIL=$FAIL"
  exit 1
fi

echo
echo "--- validate-animations-db.tcl ---"
set +e
tclsh "$ROOT/tools/validate-animations-db.tcl"
val_rc=$?
set -e
if [[ $val_rc -eq 0 ]]; then
  ok "validate-animations-db.tcl OK"
else
  fail "validate-animations-db.tcl a échoué (code $val_rc)"
fi

echo
echo "--- healthcheck.tcl ---"
set +e
tclsh "$ROOT/tools/healthcheck.tcl"
tcl_rc=$?
set -e

if [[ $tcl_rc -eq 0 ]]; then
  ok "healthcheck.tcl OK"
else
  fail "healthcheck.tcl a échoué (code $tcl_rc)"
fi

echo "------------------------------------------------------------"
echo "Résumé shell: PASS=$PASS WARN=$WARN FAIL=$FAIL"
if [[ "$FAIL" -gt 0 || "$tcl_rc" -ne 0 || "$val_rc" -ne 0 ]]; then
  exit 1
fi
exit 0
