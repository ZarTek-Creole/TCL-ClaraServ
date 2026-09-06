# Journal des changements

Ce fichier suit les changements fonctionnels et de maintenance de ClaraServ.

## [Unreleased]

| Domaine | Évolution |
|---|---|
| Runtime | ClaraServ est un service **pur Tcl** (`tclsh`) sans hôte bot tiers. |
| Legacy | Suppression du fichier de configuration hôte legacy de la branche de travail (l’historique Git peut encore le contenir — rotation des secrets recommandée ; voir `docs/SECURITY.md`). |
| Lifecycle | Contrôles standalone : stop-file, PID, poll, codes de sortie EOF/volontaire, trap Tclx optionnel. |
| Exploitation | Script `bin/claraserv-screen` (start/stop/restart/status/attach/join/logs/foreground) et exemples `systemd/`. |
| Configuration | Placeholders labo renforcés ; `runtime_dir` / `instance_name` ; préflight structurel ; optionnel `failrate` / `rate_limit_cooldown`. |
| Qualité | Makefile minimal, healthcheck, tests hors réseau, harness process local. |
| Documentation | Consolidation vers README + ARCHITECTURE / OPERATIONS / SECURITY / UNREALIRCD / CLEANUP_MANIFEST. |
| UX commandes | Réponse privée pour `!*` inconnu ; suggestion déterministe (distance 1, unique). |
| Rendu IRC | Reset final centralisé ; sanitize des pseudos ; plafond message 400 octets (DÉDUIT). |
| Random | Exclusion d’une liste de commandes sensibles historiques. |
| Animations FR | Ajout de commandes (niveaux 0+1, `<s>`, sans marque) + vague v1.3. |
| Qualité DB | Validateur `tools/validate-animations-db.tcl` intégré à `make check` (aliases/variants/fails). |
| **v1.3 enrichissement** | Alias (`db/aliases.fr.db`), variantes, fails optionnels (`failrate` défaut 0), `%keyword%`, cible multi-mots, `reload` admin PRIV, anti-flood 2s, ~30 nouvelles canoniques (réécriture originale, licence jokes non importée verbatim). |

## 1.3.1 — 2026-09-06

| Domaine | Évolution |
|---|---|
| Correctif | `!random` : suppression du double anti-flood qui empêchait toute exécution. |
| Correctif | Affichage nick : carte UID↔nick (plus d’UUID TS6 dans `!cmds` / logs / `%sender%`). |
| UX | Commande `!alias` / `alias` pour lister tous les liens alias → canonique. |

## 1.3.0 — 2026-09-05

| Domaine | Évolution |
|---|---|
| Alias | Résolution `!alias` → canonique ; `!pelle` non aliasé vers `!kiss`. |
| Variantes / fail | Fichiers `variants.fr.db` / `fails.fr.db` ; fusion avec texte historique. |
| Placeholders | `%keyword%` = forme tapée normalisée sans `!`. |
| Cible | Reste de ligne multi-mots + sanitation IRC. |
| Admin | `reload <password>` recharge les DB animations (pas la conf). |
| Anti-flood | Cooldown par salon+nick (défaut 2 s) sur animations. |

## 1.2.0 — 2026-08-28

Passage à une application Tcl autonome avec boucle événementielle sous `tclsh`.

| Domaine | Évolution |
|---|---|
| Exécution | Ajout de la boucle événementielle lors d’un démarrage direct avec `tclsh ClaraServ.tcl`. |
| Dépendances | Retrait de `logger` (tcllib) du module IRCServices ; journalisation via abstraction ClaraServ. |
| Réseau | Socket IRC non bloquant, sortie UTF-8, erreurs de liaison journalisées sans arrêt brutal de la bibliothèque. |
| Parsing | Les messages IRC sont traités comme du texte et non comme des listes Tcl. |
| Configuration | Validation des booléens, du port, du salon de journalisation et du mot de passe d’exemple. |
| Animations | Index mémoire validé au démarrage. |
| Salons | Validation du nom, égalité littérale et réécriture atomique de `salon.db`. |
| IRCD | Transmission de `serverinfo_descr` vers le message `SERVER`. |
| Qualité | Suite de régression Tcl autonome. |
| Contribution | Formulaires d’issues distincts FR/EN. |
| Documentation | README et guides d’architecture / exploitation. |

## Notes de migration

Les fichiers de configuration existants restent compatibles s’ils fournissent les clés documentées dans `ClaraServ.Example.conf`. Vérifiez que `admin_password` n’utilise pas la valeur d’exemple et exécutez `make test` avant de redémarrer une instance. Après retrait du fichier de conf hôte legacy du tracking : rotater tout secret historiquement exposé (voir [docs/SECURITY.md](docs/SECURITY.md)).
