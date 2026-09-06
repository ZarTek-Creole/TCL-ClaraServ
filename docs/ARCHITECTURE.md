# Architecture ClaraServ

ClaraServ est un **service IRC d’animation** en Tcl 8.6+. Il se connecte à l’IRCd comme **serveur de services (S2S)** via IRCServices, crée un pseudoclient, et répond aux commandes privées ou publiques (`!gaufre`, etc.). Ce n’est **pas** un bot client IRC classique (pas de NICK/USER utilisateur).

**Runtime supporté :** `tclsh ClaraServ.tcl` + modules vendored sous `modules/`.

## Couches

| Composant | Rôle | Ne doit pas contenir |
|---|---|---|
| `ClaraServ.tcl` | Conf, index animations, commandes, salons, orchestration, lifecycle | Parsing brut IRC / détails TLS |
| `modules/TCL-PKG-IRCServices/` | Socket, liaison S2S, événements, pseudoclient | Règles métier ClaraServ |
| `modules/TCL-ZCT/` | Couleurs IRC, substitutions texte | Cycle de vie processus |
| `db/database.*.db` | Catalogue d’animations | Secrets |
| `db/salon.db` | Salons persistants (runtime, non versionné) | Mot de passe admin |
| `bin/claraserv-screen` | Supervision Screen | Secrets / conf réelle |
| `systemd/` | Exemple d’unité | Secrets |

## Dépendances réelles

| Dépendance | Statut |
|---|---|
| Tcl 8.6+ | Obligatoire |
| TclTLS (`package require tls`) | Seulement si `uplink_ssl 1` |
| ZCT / IRCServices | Vendored sous `modules/` (source relatif + `package require`) |
| GNU Screen / systemd | Optionnels (supervision), hors runtime Tcl |
| Tclx | Optionnel (trap SIGTERM/SIGINT) ; absente → stop-file |

### Provenance des modules vendored

- **ZCT** — ZarTeK-Creole Tools ; licence dans `modules/TCL-ZCT/LICENSE`.
- **IRCServices** — package de liaison services ; licence dans `modules/TCL-PKG-IRCServices/LICENSE` ; dialecte orienté UnrealIRCd/TS6.

Ne pas synchroniser automatiquement depuis l’amont sans décision explicite. Ne pas modifier `ZCT.tcl` / `ircservices.tcl` sans tests dédiés.

## Chargement

1. Résolution de la racine script (`SCRIPT(dirname)`).
2. `source` de `modules/TCL-ZCT/ZCT.tcl` puis `package require ZCT`.
3. `source` de `modules/TCL-PKG-IRCServices/ircservices.tcl` puis `package require IRCServices`.
4. Si `::ClaraServ::disableAutoStart` est vrai → pas d’INIT réseau (tests / harness).
5. Sinon : `INIT` (conf + DB) → `Create:Service` → contrôles standalone → `vwait ::ClaraServ::shutdown`.

Les versions `needZct` / `needIrcs` dans `ClaraServ.tcl` doivent rester alignées avec `pkgIndex.tcl` et `package provide` (`make check`).

## Configuration

| Fichier | Versionné | Rôle |
|---|---|---|
| `ClaraServ.Example.conf` | oui | Modèle avec placeholders |
| `ClaraServ.conf` | non (gitignore) | Conf locale réelle, `chmod 600` |

Clés principales : uplink (host/port/ssl/password), `serverinfo_*`, identité service, salons, `admin_password`, `runtime_dir` / `instance_name` optionnels. Validation : `::ClaraServ::FCT::Check:Config`.

## Données `db/`

- `database.fr.db` / `database.en.db` : catalogues FR et EN (~140 cmds chacun), indexés en `dict` (`!cmd`, niveau 0|1).
- `aliases.fr.db`, `variants.fr.db`, `fails.fr.db` : enrichissement (parsers non exécutables).
- `salon.db` : runtime, non versionné ; écriture atomique.
- Rendu sortant : `Render:Outgoing` (ZCT + reset + plafond octets). Voir [COMMANDS_AND_ANIMATIONS.md](COMMANDS_AND_ANIMATIONS.md).
- Validation : `tools/validate-animations-db.tcl` (`make check`).

## Logs

`::ClaraServ::log` écrit sur **stderr** (`[LEVEL] message`). Sous systemd, stderr → journald. Aucune valeur secrète ne doit y figurer. `uplink_debug=1` peut journaliser le trafic send (dont `PASS`) — interdit hors labo court.

## Lifecycle standalone

1. `Install:Standalone:Controls` : crée `runtime_dir`, nettoie stop-file résiduel, écrit PID, poll 500 ms, trap Tclx optionnel.
2. `vwait ::ClaraServ::shutdown` (sauf si déjà en shutdown).
3. Nettoyage PID ; `exit $exitCode`.

`Request:Shutdown` est idempotent : QUIT/disconnect best-effort, pose `shutdown=1`. **Pas** de reconnexion in-process.

### Codes d’arrêt

| Situation | Code |
|---|---|
| Stop-file / arrêt volontaire | `0` |
| Erreur conf / init | non zéro (typ. `1`) |
| EOF S2S inattendu | `1` (pour `Restart=on-failure`) |
| SIGTERM sans Tclx | non intercepté (OS) |
| SIGTERM avec Tclx | `0` si trap OK (si Tclx installé) |

## Architecture S2S (résumé)

Ordre typique TS6 via IRCServices : `PASS` → `PROTOCTL` → `SERVER` → `EOS`, puis UID / SJOIN / MODE. PING→PONG automatique. Dialecte orienté **UnrealIRCd** ; ne pas assumer InspIRCd sans labo. Détails : [UNREALIRCD.md](UNREALIRCD.md).

## Robustesse

- Socket non bloquant ; `fileevent` ; messages IRC = texte découpé par regexp (`Message:Words`), jamais comme liste Tcl.
- TLS côté IRCServices : `tls::socket -require 0 -request 0` (pas de validation CA client aujourd’hui).

## Non supporté / limites

- Client IRC classique.
- Reconnexion in-process après EOF (le superviseur redémarre).
- Validation certificat peer TLS côté ClaraServ.
- IRCd autre qu’Unreal sans validation labo.
- Connexion IRCd réelle hors validation humaine explicite.

## Supervision

- Foreground : `tclsh ClaraServ.tcl`
- Screen : `bin/claraserv-screen` ([OPERATIONS.md](OPERATIONS.md))
- systemd : exemple `systemd/claraserv.service` (non installé par le dépôt)

## Règles de compatibilité

- Cible Tcl **8.6+** (pas d’exigence Tcl 9 sans décision).
- Ne pas changer le protocole S2S sans preuve (tests ou labo autorisé).
- Ne pas transformer ClaraServ en bot client.
