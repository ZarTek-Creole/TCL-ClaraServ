# Commandes et animations ClaraServ

Guide concis pour utilisateurs et contributeurs. Runtime : service S2S Tcl (`tclsh`).

## Aide rapide

| Besoin | Commande |
|---|---|
| Liste des animations | `!cmds` (liste en privé) |
| Aide | `!help` |
| Animation aléatoire | `!random` `[cible]` |
| Animation | `!<commande>` ou `!<commande> <cible…>` |
| Admin (privé) | `join` / `part` / `reload` + mot de passe |

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
| `!cmd` | 0 | `%sender%`, `%keyword%` |
| `!cmd cible…` | 1 | `%sender%`, `%pseudo%`, `%keyword%` |

Tout après le nom de commande forme la **cible multi-mots** (espaces conservés après trim). Contrôles IRC / CR / LF retirés avant insertion.

`%keyword%` = commande **tapée** (après normalisation), **sans** `!` (ex. `!bisous` → `bisous`), même si un alias résout vers une autre animation.

## Alias

Fichier `db/aliases.fr.db` (lignes `!alias !canonique`, parser non-exécutable).

Commande dédiée : **`!alias`** (salon) ou **`alias`** (privé) — liste tous les liens `alias → canonique`.

Exemples : `!bisous` → `!kiss`, `!applause` → `!applaudir`, `!cacao` → `!chocolat`, `!prout` → `!pouet`, `!beer` → `!bière`, …

`!pelle` est une **commande propre** (pas un alias de `!kiss`).

Les formes sans accent (`!cafe`, `!biere`, `!calin`, `!the`, …) correspondent déjà aux commandes accentuées via la normalisation.

`!cmds` liste les **canoniques** et renvoie vers `!alias` pour les liens.

## Variantes et échecs

| Fichier | Rôle |
|---|---|
| `db/variants.fr.db` | Variantes supplémentaires (fusionnées avec le texte historique) |
| `db/fails.fr.db` | Textes d’échec |

- Tirage aléatoire parmi les variantes disponibles.
- `failrate` (conf optionnelle, défaut **0**) : pourcentage 0–100 ; si `> 0` et qu’il existe des fails, chance d’utiliser un texte d’échec.
- Anti-flood : cooldown configurable `rate_limit_cooldown` (défaut **2** s) par salon+expéditeur sur les animations (`!random` / dynamiques) — silence si limité.

## Commandes système

| Commande | Public / privé | Notes |
|---|---|---|
| `!help` / `help` | PUB+PRIV / PRIV | Aide |
| `!cmds` / `cmds` | PUB+PRIV / PRIV | Liste animations |
| `!alias` / `alias` | PUB+PRIV / PRIV | Liste alias → canoniques |
| `!about` / `about` | PUB+PRIV / PRIV | Version |
| `!random` | PUB | Tire au sort (voir sensible) |
| `join` / `part` / `reload` | PRIV admin | Salons / recharge DB animations |

## Animations FR / EN

| Fichier | État |
|---|---|
| `db/database.fr.db` | Production FR |
| `db/aliases.fr.db` / `variants.fr.db` / `fails.fr.db` | Enrichissement FR |
| `db/database.en.db` | **Exemple seulement** — traduction reportée |

Format historique : `{{!cmd} {0\|1} {texte}}` dans `variable database { … }`. UTF-8.

### Rendu IRC

Balises ZCT : `<cNN>`, `<b>`/`</b>`, `<u>`, `<i>`, **`<s>` = reset `\x0f`**.

Le moteur `Render:Outgoing` :

- applique les balises ;
- impose **un** reset final si un style est présent ;
- borne le texte à **400 octets** UTF-8 (**DÉDUIT**) sans couper un codepoint ni une séquence de contrôle en fin.

Palette pour **nouvelles** lignes : texte `12`, expéditeur `07`, cible `06`/`13`, accent `04`, fin `<s>`.

### Marques (historique)

Commandes type boissons/restau nommées (`!vittel`, `!redbull`, `!macdo`, `!coca`, …) : **conservées temporairement**. Aucune nouvelle marque. Aucun alias marque.

### Contenu sensible (historique)

Entrées existantes conservées. `!random` **exclut** une liste code : `!sexy`, `!string`, `!fesses`, `!fessée`, `!fouet`. Appel direct toujours possible. Pas de nouvel adult. Alias vers sensibles refusés.

### Contribution

- Toujours niveaux **0 et 1**.
- Nouvelles lignes : `<s>` final, gras apparié, pas de marque / sensible.
- Variantes / fails / alias : fichiers dédiés (voir ci-dessus).
- Valider : `tclsh tools/validate-animations-db.tcl` (aussi via `make check`).
- Tests : `make test`.

## Unicode

UTF-8 ; emoji facultatifs ; le sens du message ne doit pas dépendre de la couleur ni de l’emoji.
