# Manifeste de nettoyage du dépôt

Journal concis des suppressions et consolidations importantes. Ne pas y accumuler de rapports temporaires.

| Élément retiré/consolidé | Pourquoi | Remplacement | Compatibilité |
|---|---|---|---|
| `eggdrop.conf` | Hors runtime pur Tcl ; secrets possibles | Runtime `tclsh` + `ClaraServ.conf` locale | Historique Git peut encore contenir le fichier ; rotation obligatoire ; pas de purge |
| Mentions Eggdrop actives (README, ARCHITECTURE, OPERATIONS, templates) | Runtime autonome uniquement | Docs pérennes sans méthode Eggdrop | Mentions historiques limitées à SECURITY + ce manifeste |
| Soft-guards / compat Eggdrop dans `ClaraServ.tcl` | Déjà remplacés par `::ClaraServ::log` + lifecycle standalone | stderr / stop-file / vwait | Modules vendored non modifiés (ZCT peut encore détecter `putlog` s’il existe) |
| `docs/*.html`, TclDoc, `ChangeLog.html`, `tools/tcldoc/`, `tools/release`, `tools/update` | Générés / clutter | — | — |
| Meta modules (`.thoth`, `.devcontainer`, `DONATE`, `setup.tcl`, `example.tcl`, docs ZCT HTML) | Non requis runtime | LICENSE + README module | — |
| Rapports Cursor temporaires (`DOCUMENTATION_*`, `REPOSITORY_*`, `NEXT_PHASES_BRIEF`, `*_REPORT`, `BOOTSTRAP_*`, `LOT_*`, `CHECKPOINT_*`) | Redondants | README + ARCHITECTURE + OPERATIONS + SECURITY + UNREALIRCD | — |
| `docs/examples/unrealircd-*.example`, `systemd/README.md` | Doublons | UNREALIRCD.md / OPERATIONS.md | — |
| `.devcontainer/`, `.vscode/settings.json`, `.thoth.yaml`, `DONATE` | Hors runtime | — | — |

## Conservations volontaires

| Élément | Justification |
|---|---|
| `modules/TCL-ZCT/`, `modules/TCL-PKG-IRCServices/` | Runtime + licences ; pas de sync amont automatique |
| `bin/claraserv-screen`, `systemd/` | Exploitation documentée |
| `tests/`, `tools/healthcheck*`, `preflight*`, `test-*`, `bootstrap-dev.sh` | Contrôles hors réseau |
| `run/.gitkeep` | Préserve le répertoire runtime vide |
| `.github/` | Contribution |
| `docs/CLEANUP_MANIFEST.md` | Seul journal permanent des suppressions |

## Inventaire Eggdrop (synthèse)

| Catégorie | Action |
|---|---|
| CODE_ACTIVE ClaraServ | Logging standalone ; pas de `putlog` / binds |
| CODE_MORT / HISTORIQUE modules vendored | Laissé intact (interdiction de modifier le vendoring) |
| TEST | Asserte l’absence de `putlog` et le chargement sous `tclsh` |
| DOCUMENTATION utilisateur | Nettoyée ; historique dans SECURITY + ce fichier |
| CONFIG_LEGACY `eggdrop.conf` | `git rm` de la branche de travail |
