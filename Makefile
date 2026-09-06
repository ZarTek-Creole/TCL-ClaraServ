# Makefile produit ClaraServ — hors réseau IRCd.
.PHONY: help check test verify-systemd

ROOT := $(CURDIR)

help:
	@echo "Cibles produit:"
	@echo "  make check           — healthcheck + validateur DB"
	@echo "  make test            — tests/test_claraserv.tcl"
	@echo "  make verify-systemd  — systemd-analyze verify (si présent)"

check:
	@tclsh "$(ROOT)/tools/healthcheck.tcl"

test:
	@tclsh "$(ROOT)/tests/test_claraserv.tcl"

verify-systemd:
	@if command -v systemd-analyze >/dev/null 2>&1; then \
	  systemd-analyze verify "$(ROOT)/systemd/claraserv.service" && echo "PASS: systemd-analyze verify"; \
	else \
	  echo "WARN: systemd-analyze absent — vérification unit non exécutée."; \
	fi
