#!/usr/bin/env bash
# Tests hors session screen réelle — pas d’install, pas de screen -dm.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCR="$ROOT/bin/claraserv-screen"
fail=0

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $msg (got=$got want=$want)" >&2
    fail=1
  else
    echo "PASS: $msg"
  fi
}

bash -n "$SCR"
echo "PASS: bash -n"

"$SCR" --help >/dev/null
assert_eq "$?" 0 "--help"

set +e
"$SCR" --dry-run status >/dev/null
rc=$?
set -e
# inactif ou screen absent → 1 attendu
[[ "$rc" -eq 0 || "$rc" -eq 1 ]] || { echo "FAIL: dry-run status rc=$rc"; fail=1; }
echo "PASS: --dry-run status (rc=$rc)"

"$SCR" --dry-run start >/dev/null
assert_eq "$?" 0 "--dry-run start"

"$SCR" --dry-run stop >/dev/null
assert_eq "$?" 0 "--dry-run stop"

set +e
"$SCR" --not-an-option start >/dev/null 2>&1
rc=$?
set -e
assert_eq "$rc" 2 "option inconnue → 2"

set +e
"$SCR" --session 'bad name' status >/dev/null 2>&1
rc=$?
set -e
assert_eq "$rc" 2 "session invalide → 2"

set +e
"$SCR" --instance 'bad name' --dry-run status >/dev/null 2>&1
rc=$?
set -e
assert_eq "$rc" 2 "instance invalide → 2"

set +e
"$SCR" --timeout 0 --dry-run stop >/dev/null 2>&1
rc=$?
set -e
assert_eq "$rc" 2 "timeout invalide → 2"

set +e
"$SCR" --timeout abc --dry-run stop >/dev/null 2>&1
rc=$?
set -e
assert_eq "$rc" 2 "timeout non numérique → 2"

if ! command -v screen >/dev/null 2>&1; then
  set +e
  "$SCR" start >/dev/null 2>&1
  rc=$?
  set -e
  assert_eq "$rc" 1 "start sans screen → 1"
  echo "NOTE: screen ABSENT — sessions réelles NOT_TESTED"
else
  echo "NOTE: screen présent — tests de session réelle hors périmètre de ce script"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "FAIL: tests claraserv-screen"
  exit 1
fi
echo "PASS: tests claraserv-screen (statique / dry-run)"
exit 0
