# Commandes et animations ClaraServ

Guide concis pour utilisateurs et contributeurs. Runtime : service S2S Tcl (`tclsh`).

## Aide rapide

| Besoin | Commande |
|---|---|
| Liste des animations | `!cmds` (liste en privé) |
| Aide | `!help` |
| Animation aléatoire | `!random` `[pseudo]` |
| Animation | `!<commande>` ou `!<commande> <pseudo>` |
| Admin (privé) | `join` / `part` + mot de passe |

## Commande inconnue (salon)

Si le message commence par `!` et que la commande n’existe pas :

1. **Suggestion** si une seule commande publique connue est à distance d’édition **1** (ex. `!cmdss` → `!cmds`).
2. Sinon : *Commande inconnue. Utilisez !cmds…*
3. Une seule réponse, en **privé** à l’auteur (pas de flood salon).
4. Pas de suggestion pour les commandes admin ; pas de suggestion si plusieurs voisins (ex. `!cms` est ambigu avec `!mms` et `!cmds`).

Sans préfixe `!` : aucune réaction.

## Cibles

| Forme | Niveau DB | Placeholders |
|---|---|---|
| `!cmd` | 0 | `%sender%` (auto) |
| `!cmd pseudo` | 1 | `%sender%`, `%pseudo%` |

Arguments au-delà du premier pseudo : ignorés. Pseudos : contrôles IRC / CR / LF retirés avant insertion.

## Commandes système

| Commande | Public / privé | Notes |
|---|---|---|
| `!help` / `help` | PUB+PRIV / PRIV | Aide |
| `!cmds` / `cmds` | PUB+PRIV / PRIV | Liste animations |
| `!about` / `about` | PUB+PRIV / PRIV | Version |
| `!random` | PUB | Tire au sort (voir sensible) |
| `join` / `part` | PRIV admin | Salons persistants |

**Alias** : aucun.

## Animations FR / EN

| Fichier | État |
|---|---|
| `db/database.fr.db` | Production FR — ~108 commandes (90 historiques + ajouts) |
| `db/database.en.db` | **Exemple seulement** — traduction reportée |

Format : `{{!cmd} {0\|1} {texte}}` dans `variable database { … }`. Une ligne par couple (cmd, niveau). UTF-8.

### Rendu IRC

Balises ZCT : `<cNN>`, `<b>`/`</b>`, `<u>`, `<i>`, **`<s>` = reset `\x0f`**.

Le moteur `Render:Outgoing` :

- applique les balises ;
- impose **un** reset final si un style est présent (neutralise gras/couleur orphelins historiques) ;
- borne le texte à **400 octets** UTF-8 (**DÉDUIT**, hors préfixe IRC) sans couper un codepoint ni une séquence de contrôle en fin.

Palette pour **nouvelles** lignes : texte `12`, expéditeur `07`, cible `06`/`13`, accent `04`, fin `<s>`.

### Marques (historique)

Commandes type boissons/restau nommées (`!vittel`, `!redbull`, `!macdo`, `!coca`, …) : **conservées temporairement**. Aucune nouvelle marque. Décision future : maintien / générique / dépréciation / suppression.

### Contenu sensible (historique)

Entrées existantes conservées. `!random` **exclut** une liste code : `!sexy`, `!string`, `!fesses`, `!fessée`, `!fouet`. Appel direct de ces commandes toujours possible. Pas de nouveau contenu sensible.

### Contribution

- Toujours niveaux **0 et 1**.
- Nouvelles lignes : `<s>` final, gras apparié, pas de marque / sensible.
- Valider : `tclsh tools/validate-animations-db.tcl` (aussi via `make check`).
- WARN sur anciennes lignes sans `<s>` / gras impair : attendu ; nettoyage progressif.
- Tests : `make test` (inconnu, typo, reset, sanitize, longueur, nouvelles cmds, fixture invalide).

## Unicode

UTF-8 ; emoji facultatifs ; le sens du message ne doit pas dépendre de la couleur ni de l’emoji.
