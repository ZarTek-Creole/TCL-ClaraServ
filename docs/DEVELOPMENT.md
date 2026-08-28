# Guide de développement ClaraServ

Ce guide décrit comment étendre ClaraServ sans mélanger le protocole IRC, les commandes et le stockage. La règle principale est simple : **une fonctionnalité visible doit être testable sans IRCD ni Eggdrop**.

## Organisation du code

| Emplacement | Contenu autorisé | Exemple |
|---|---|---|
| `ClaraServ.tcl` | Commandes, validation, orchestration, index des animations | `::ClaraServ::IRC:CMD:PUB:*` |
| `modules/TCL-PKG-IRCServices` | Framing IRC, socket TCP/TLS, événements de protocole | `PRIVMSG`, `UID`, `EOS` |
| `modules/TCL-ZCT` | Fonctions de texte sans état réseau | couleurs IRC, substitutions |
| `db/database.*.db` | Données d’animations, pas de logique Tcl générale | `{{!salut} {0} {...}}` |
| `tests/` | Tests autonomes exécutés par `tclsh` | parsing et persistance |

## Ajouter une commande publique

Une commande publique est une procédure dans l’espace de noms `::ClaraServ::IRC:CMD:PUB`. Elle reçoit toujours `sender`, `destination`, `command` et `data`. Les arguments provenant du réseau doivent être traités comme des **données**, jamais injectés dans `eval` ou dans une commande construite par concaténation.

```tcl
proc ::ClaraServ::IRC:CMD:PUB:VERSION {sender destination command data} {
    variable ::ClaraServ::SCRIPT
    ::ClaraServ::FCT::SENT:PRIVMSG $destination \
        [format "ClaraServ v%s" $SCRIPT(version)]
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}
```

L’utilisateur l’appellera avec `!version`. Le routeur retire le préfixe `!`, convertit le nom en majuscules pour trouver la procédure et préserve la liste des arguments dans `data`.

## Ajouter une commande privée

Utilisez le même modèle dans `::ClaraServ::IRC:CMD:PRIV`. Les opérations qui modifient les salons ou un stockage doivent impérativement valider leurs arguments. `join` et `part` montrent comment retourner `0` en cas d’échec et `1` en cas de réussite.

Les commandes administratives ne doivent pas être ajoutées au moyen d’un mot de passe permanent transmis sur un réseau non chiffré. Pour toute nouvelle capacité sensible, concevez une ACL explicite : compte IRC identifié, masque d’hôte autorisé ou identifiant local avec empreinte de mot de passe.

## Ajouter une animation

Les animations ne demandent pas de code. Chaque commande requiert une entrée niveau `0` et une entrée niveau `1` :

```tcl
{{!bravo} {0} {<c07>%sender%<c12> se félicite.}}
{{!bravo} {1} {<c07>%sender%<c12> félicite <c04>%pseudo%<c12>.}}
```

Au démarrage, `::ClaraServ::FCT::DB:Index` vérifie le format et prépare un index en mémoire. Une commande en doublon ou un niveau invalide fait échouer proprement le chargement, plutôt que de produire un résultat ambigu en production.

## Conventions Tcl

Les conventions suivantes évitent les défauts les plus coûteux dans les scripts Tcl réseau.

| Règle | À faire | À éviter |
|---|---|---|
| Exécution dynamique | `[list {*}$procedure {*}$arguments]` avec `catch` | `eval` sur des données reçues |
| Chaînes | Utiliser des accolades pour les littéraux contenant `[` ou `]` | `format "[%s]"` : les crochets déclenchent une substitution |
| Entrées IRC | Découper les mots par expression régulière | Passer le texte IRC directement à `lindex` comme liste Tcl |
| Erreurs | `return -code error`, `catch` et journalisation contextualisée | `exit` depuis une bibliothèque réutilisable |
| Fichiers | `try … finally` et renommage atomique | Fichier ouvert ou écriture directe non protégée |
| Namespace | Procédures entièrement qualifiées et variables déclarées | Variables globales implicites |

## Écrire un test

Le harnais `tests/test_claraserv.tcl` ne charge pas la configuration réelle et définit un robot simulé. Ajoutez un test au plus près de la fonction modifiée, puis exécutez :

```bash
tclsh tests/test_claraserv.tcl
```

Le scénario minimal d’une commande consiste à indexer la base, remplacer `::ClaraServ::BOT_ID` par un mock, appeler `::ClaraServ::FCT::Dispatch:Message` puis vérifier les messages enregistrés. Testez aussi les entrées vides, une syntaxe invalide et les caractères spéciaux Tcl (`{`, `}`, `[`, `]`, `$`, `;`).

## Feuille de route technique

Les évolutions de plus forte valeur sont les suivantes, dans cet ordre :

1. Ajouter une politique anti-inondation par utilisateur et par salon, purement en mémoire au départ.
2. Remplacer le secret administratif transmis dans un message privé par une ACL basée sur l’identité IRC.
3. Introduire une interface `Storage` pour proposer un adaptateur SQLite optionnel sans casser les fichiers `.db` existants.
4. Séparer les variantes de protocole par adaptateur IRCD, car `PROTOCTL` et `SID` ne suffisent pas à représenter toutes les familles IRC.
5. Ajouter des tests d’intégration avec une maquette TCP locale pour vérifier les séquences `UID`, `PRIVMSG`, `PING` et `EOS`.

Consultez également la [décision d’architecture](ARCHITECTURE.md) avant de modifier la couche transport.
