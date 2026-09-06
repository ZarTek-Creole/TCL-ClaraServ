# Journal des changements

## [Unreleased]

| Domaine | Évolution |
|---|---|
| Dépôt | Scripts atelier hors produit ; docs allégées ; Example conf sans dump modes IRCd ; retrait `run/.gitkeep`. |
| Qualité | Un seul `tools/healthcheck.tcl` (plus de `.sh`) ; validateur sans WARN style historique. |
| Animations | `database.en.db` : traduction complète depuis `database.fr.db` (278 entrées). |

## 1.3.3 — 2026-09-06

| Domaine | Évolution |
|---|---|
| Correctif | Annonces salon `!help` / `!about` : plus d’UID TS6 à la place du nick. |
| Correctif | `Nickmap:Resolve` n’accepte plus nick→UID (UID_CONVERT bidirectionnel). |
| Runtime | Apprentissage UID↔nick aussi sur PRIVMSG (`who`/`who2`). |

## 1.3.2 — 2026-09-06

| Domaine | Évolution |
|---|---|
| Conf | Example : `service_chanmodes` défaut `""` ; doc anti-`+O` sur salon public. |
| Runtime | EOS n’envoie plus `MODE` salon si `service_chanmodes` vide. |

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
| Exécution | Boucle événementielle via `tclsh ClaraServ.tcl`. |
| Dépendances | Retrait de `logger` (tcllib) du module IRCServices. |
| Réseau | Socket non bloquant, UTF-8, erreurs de liaison journalisées. |
| Parsing | Messages IRC traités comme texte, pas listes Tcl. |
| Configuration | Validation booléens / port / salon / mot de passe d’exemple. |
| Animations | Index mémoire validé au démarrage. |
| Salons | `salon.db` atomique. |
| Qualité | Suite de régression Tcl autonome. |

## Notes de migration

Les confs existantes restent compatibles si les clés de `ClaraServ.Example.conf` sont fournies. Vérifier `admin_password` ≠ valeur d’exemple ; `make test` avant redémarrage. Après retrait d’éventuels secrets legacy de l’historique : rotater (voir [docs/SECURITY.md](docs/SECURITY.md)).
