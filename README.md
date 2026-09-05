# ClaraServ

**ClaraServ** est un service IRC d’animation en **Tcl 8.6+**. Les utilisateurs déclenchent des animations (`!gaufre`, …) depuis un salon. ClaraServ se lie à l’IRCd comme **serveur de services (S2S)** via les modules vendored ZCT et IRCServices — ce n’est **pas** un bot client IRC classique.

## Capacités

- Catalogue d’animations FR (~140 cmds ; EN = exemple), commandes privées et publiques
- Alias (`db/aliases.fr.db`), variantes / fails optionnels, cible multi-mots, `%keyword%`
- Aide `!cmds` / `!help` ; suggestion si faute de frappe proche (distance 1)
- Rendu IRC avec reset final ; pseudos nettoyés des contrôles
- Persistance des salons dans `db/salon.db` ; `reload` admin (DB animations)
- Anti-flood configurable sur les animations
- Runtime `tclsh` autonome + modules sous `modules/`
- Arrêt propre par stop-file (exit 0) ; EOF S2S → exit non nul
- Exploitation optionnelle via GNU Screen ou systemd

## Architecture

Service Tcl **S2S** (PASS/SERVER/UID/SJOIN via IRCServices). Pas de NICK/USER client. Détails : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Prérequis

| Élément | Condition |
|---|---|
| Tcl | 8.6+ |
| TclTLS | seulement si `uplink_ssl 1` |
| Modules | Inclus (`TCL-ZCT`, `TCL-PKG-IRCServices`) |
| GNU Screen / systemd | Optionnels (exploitation) |

## Installation

```bash
git clone https://github.com/ZarTek-Creole/TCL-ClaraServ.git
cd TCL-ClaraServ
cp ClaraServ.Example.conf ClaraServ.conf
chmod 600 ClaraServ.conf
```

Éditer `ClaraServ.conf` : remplacer tous les placeholders. **Ne jamais committer** ce fichier. Voir [SECURITY](docs/SECURITY.md) et [UnrealIRCd S2S](docs/UNREALIRCD.md).

## Démarrage foreground

```bash
tclsh ClaraServ.tcl
```

## Arrêt propre

```bash
touch run/claraserv.stop
# multi-instance : touch run/<instance>/claraserv.stop
```

## Tests et vérifications (hors réseau IRCd)

```bash
make check
make test
make test-local-process
make verify-screen
make verify-systemd
make preflight-config   # nécessite ClaraServ.conf locale
```

## Exploitation

| Mode | Entrée |
|---|---|
| Foreground | `tclsh ClaraServ.tcl` |
| GNU Screen | `bin/claraserv-screen start\|stop\|restart\|status\|attach\|join\|logs\|foreground` |
| systemd | exemple `systemd/claraserv.service` (non activé par le dépôt) |

Guide complet : [docs/OPERATIONS.md](docs/OPERATIONS.md). Les sessions screen réelles et l’activation systemd ne sont **pas** exécutées par les cibles `make`.

## Documentation

| Besoin | Document |
|---|---|
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Exploitation | [docs/OPERATIONS.md](docs/OPERATIONS.md) |
| Commandes / animations | [docs/COMMANDS_AND_ANIMATIONS.md](docs/COMMANDS_AND_ANIMATIONS.md) |
| Sécurité | [docs/SECURITY.md](docs/SECURITY.md) |
| S2S UnrealIRCd | [docs/UNREALIRCD.md](docs/UNREALIRCD.md) |
| Suppressions dépôt | [docs/CLEANUP_MANIFEST.md](docs/CLEANUP_MANIFEST.md) |

## Contribution

- Issues : modèles FR/EN sous `.github/ISSUE_TEMPLATE/`
- Avant une PR : `make check` et `make test`
- Ne pas versionner `ClaraServ.conf`, logs, PID ou secrets
- Ne pas synchroniser automatiquement les modules vendored depuis l’amont

## Licence

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) — voir `LICENSE`.
