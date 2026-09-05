# Makefile minimal ClaraServ — aucune connexion réseau / IRCd / service persistant.
.PHONY: help bootstrap check test test-local-process preflight-config verify-systemd verify-screen test-screen

ROOT := $(CURDIR)

help:
	@echo "Cibles ClaraServ:"
	@echo "  make help               — cette aide"
	@echo "  make bootstrap          — détection env (sans install)"
	@echo "  make check              — healthcheck statique (Bash + Tcl)"
	@echo "  make test               — tests/test_claraserv.tcl"
	@echo "  make test-local-process — lifecycle stop-file hors IRCd"
	@echo "  make test-screen        — tests statiques / dry-run du lanceur screen"
	@echo "  make verify-screen      — présence screen + test-screen (pas de session réelle)"
	@echo "  make verify-systemd     — systemd-analyze verify (si présent)"
	@echo "  make preflight-config   — structure ClaraServ.conf (aucune valeur affichée)"
	@echo ""
	@echo "Aucune cible ne se connecte à un IRCd réel ni ne démarre systemd/screen."

bootstrap:
	@bash "$(ROOT)/tools/bootstrap-dev.sh"

check:
	@bash "$(ROOT)/tools/healthcheck.sh"

test:
	@echo "Exécution de la suite de régression autonome…"
	@tclsh "$(ROOT)/tests/test_claraserv.tcl"

test-local-process:
	@echo "Test process local contrôlé (harness, sans IRCd / sans conf réelle)…"
	@bash "$(ROOT)/tools/test-local-process.sh"

test-screen:
	@bash "$(ROOT)/tools/test-claraserv-screen.sh"

verify-screen: test-screen
	@if command -v screen >/dev/null 2>&1; then \
	  echo "WARN: screen présent — sessions réelles NOT_TESTED (pas de démarrage ici)."; \
	else \
	  echo "WARN: screen ABSENT — validation limitée à help/dry-run/erreurs."; \
	fi

verify-systemd:
	@if command -v systemd-analyze >/dev/null 2>&1; then \
	  systemd-analyze verify "$(ROOT)/systemd/claraserv.service" && echo "PASS: systemd-analyze verify"; \
	else \
	  echo "WARN: systemd-analyze absent — vérification unit non exécutée."; \
	fi

preflight-config:
	@echo "Préflight structurel ClaraServ.conf (valeurs non affichées)…"
	@tclsh "$(ROOT)/tools/preflight-claraserv-config.tcl"
