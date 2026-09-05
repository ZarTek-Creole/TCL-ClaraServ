#!/usr/bin/env bash
# Bootstrap développement ClaraServ — non destructif, sans sudo, sans install auto.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
WARN=0
FAIL=0

usage() {
  cat <<'EOF'
Usage: tools/bootstrap-dev.sh [--help]

Vérifie l'environnement de développement ClaraServ sans modifier le système.
- Aucun sudo
- Aucune installation automatique
- Aucune connexion réseau
- Aucun secret affiché

Codes de sortie:
  0  prérequis obligatoires OK (warnings possibles)
  1  prérequis obligatoire manquant ou dépôt incomplet
  2  usage / erreur interne
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

hr() { printf '%s\n' "------------------------------------------------------------"; }
ok()   { printf '[PASS] %s\n' "$*"; PASS=$((PASS + 1)); }
warn() { printf '[WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
fail() { printf '[FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }

hr
echo "ClaraServ — bootstrap-dev"
echo "Racine: $ROOT"
hr

# --- OS ---
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  ok "OS: ${PRETTY_NAME:-inconnu}"
else
  warn "OS: /etc/os-release absent ($(uname -s 2>/dev/null || echo inconnu))"
fi

# --- Outils obligatoires ---
if command -v tclsh >/dev/null 2>&1; then
  TCL_VER="$(tclsh <<<'puts [info patchlevel]' 2>/dev/null || true)"
  if [[ -n "${TCL_VER}" ]]; then
    ok "tclsh présent ($TCL_VER)"
    case "$TCL_VER" in
      8.6*|8.7*|9.*) ;;
      *) warn "Tcl $TCL_VER — projet ciblé 8.6+" ;;
    esac
  else
    fail "tclsh présent mais ne répond pas"
  fi
else
  fail "tclsh absent (obligatoire)"
fi

if command -v git >/dev/null 2>&1; then
  ok "git présent ($(git --version | awk '{print $3}'))"
else
  fail "git absent (obligatoire pour le workflow dépôt)"
fi

# --- Recommandés ---
for cmd in make timeout awk sed grep find; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd présent"
  else
    warn "$cmd absent (recommandé)"
  fi
done

if command -v shellcheck >/dev/null 2>&1; then
  ok "shellcheck présent"
else
  warn "shellcheck absent (recommandé pour scripts)"
fi

if command -v systemctl >/dev/null 2>&1; then
  ok "systemctl présent"
else
  warn "systemctl absent"
fi

if command -v systemd-analyze >/dev/null 2>&1; then
  ok "systemd-analyze présent"
else
  warn "systemd-analyze absent"
fi

# --- Optionnels ---
for cmd in screen tclsh8.6 tclsh9.0 docker podman bats shfmt nagelfar; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd présent (optionnel)"
  else
    warn "$cmd absent (optionnel)"
  fi
done

# --- Packages Tcl ---
if command -v tclsh >/dev/null 2>&1; then
  TLS_OUT="$(tclsh <<<'if {[catch {package require tls} v]} {puts ABSENT} else {puts $v}' 2>/dev/null || echo ABSENT)"
  if [[ "$TLS_OUT" != "ABSENT" ]]; then
    ok "package tls Tcl ($TLS_OUT) — requis si uplink_ssl=1"
  else
    warn "package tls Tcl absent — obligatoire seulement avec TLS"
  fi
fi

# --- Fichiers dépôt ---
REQUIRED_FILES=(
  ClaraServ.tcl
  ClaraServ.Example.conf
  modules/TCL-ZCT/ZCT.tcl
  modules/TCL-ZCT/pkgIndex.tcl
  modules/TCL-PKG-IRCServices/ircservices.tcl
  modules/TCL-PKG-IRCServices/pkgIndex.tcl
  db/database.fr.db
  db/database.en.db
  tests/test_claraserv.tcl
  docs/ARCHITECTURE.md
  docs/OPERATIONS.md
  docs/SECURITY.md
  docs/UNREALIRCD.md
  bin/claraserv-screen
  systemd/claraserv.service
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$ROOT/$f" ]]; then
    ok "fichier $f"
  else
    fail "fichier manquant: $f"
  fi
done

if [[ -f "$ROOT/ClaraServ.conf" ]]; then
  warn "ClaraServ.conf présent (local) — valeurs non affichées"
else
  ok "ClaraServ.conf absent (normal en clone frais ; copier depuis Example)"
fi

# --- Contrôles statiques disponibles ---
if [[ -x "$ROOT/tools/healthcheck.sh" ]] || [[ -f "$ROOT/tools/healthcheck.sh" ]]; then
  echo
  hr
  echo "Lancement healthcheck…"
  hr
  if bash "$ROOT/tools/healthcheck.sh"; then
    ok "healthcheck terminé avec succès"
  else
    hc=$?
    if [[ $hc -eq 1 ]]; then
      fail "healthcheck a signalé des échecs"
    else
      warn "healthcheck code $hc"
    fi
  fi
else
  warn "tools/healthcheck.sh absent — saute"
fi

hr
echo "Résumé bootstrap-dev: PASS=$PASS WARN=$WARN FAIL=$FAIL"
echo
echo "Actions manuelles éventuelles:"
echo "  cp ClaraServ.Example.conf ClaraServ.conf && chmod 600 ClaraServ.conf"
echo "  # Éditer ClaraServ.conf (ne jamais committer)"
echo "  # apt install tcl tcl-tls shellcheck screen   # si manquants, avec accord"
echo "  make test"
hr

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
