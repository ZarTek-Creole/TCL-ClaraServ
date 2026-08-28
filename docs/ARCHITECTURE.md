# Architecture de ClaraServ

![Schéma de l’architecture cible](architecture.png)

ClaraServ est un **service d’animation IRC** qui se connecte à l’IRCD en tant que serveur de services, crée un pseudoclient et répond aux commandes privées ou publiques. Son objectif reste volontairement simple : apporter des animations configurables, sûres et faciles à maintenir. La version 1.2.0 isole les responsabilités en trois couches : la logique métier dans `ClaraServ.tcl`, les transformations de texte dans ZCT et le transport IRC dans IRCServices.

> **Décision d’architecture :** Eggdrop ne doit plus être une dépendance d’exécution de ClaraServ. Il peut rester un hôte facultatif pour les installations qui l’utilisent déjà, mais le mode recommandé est l’exécution directe par `tclsh` sous supervision de `systemd`.

## Pourquoi Tcl autonome est adapté

Eggdrop apporte des commandes supplémentaires pour le cycle de vie d’un bot IRC, la partyline, la gestion d’utilisateurs et les files d’envoi ; sa documentation distingue explicitement ces commandes de Tcl standard. Par exemple, `putserv` et `puthelp` placent les messages dans des files d’envoi contrôlées par Eggdrop, tandis que `putlog` écrit dans le journal et la partyline [1]. ClaraServ n’utilisait toutefois pas ces mécanismes pour établir sa liaison serveur ou pour traiter les messages : la connexion, le socket et les événements sont déjà assurés par IRCServices.

Tcl 8.6 fournit nativement `socket` pour ouvrir des connexions TCP et `fileevent` pour recevoir des données sans bloquer la boucle événementielle [2] [3]. IRCServices s’appuie désormais sur ces primitives de façon non bloquante. Le script principal reste compatible avec Eggdrop si celui-ci le charge, mais l’exécution directe par `tclsh ClaraServ.tcl` démarre sa propre attente événementielle.

| Critère | Exécution sous Eggdrop | Exécution autonome Tcl | Choix pour ClaraServ |
|---|---|---|---|
| Dépendances | Eggdrop, ses modules et son cycle de vie | Tcl 8.6+, TclTLS uniquement si TLS | **Tcl autonome** |
| Connexion serveur IRC | Abstractions Eggdrop possibles, non utilisées ici | Socket et événements gérés par IRCServices | **Tcl autonome** |
| Supervision | Partyline / fonctions d’administration Eggdrop | `systemd`, journald, redémarrage automatique | **Tcl autonome** |
| Authentification / base d’utilisateurs Eggdrop | Disponible | À reconstruire si nécessaire | Eggdrop seulement si ces fonctions sont requises |
| Compatibilité historique | Native | Maintenue via chargement optionnel | Les deux pendant la transition |

Le bénéfice principal est une réduction nette du couplage : le processus qui fournit l’animation est le même processus qui gère sa connexion IRC. En contrepartie, l’exploitation doit remplacer la partyline Eggdrop par des outils standard du système, et les futures fonctions qui s’appuieraient sur les comptes/flags Eggdrop devront avoir leur propre modèle d’autorisation.

## Responsabilités des composants

| Composant | Responsabilité | Ne doit pas contenir |
|---|---|---|
| `ClaraServ.tcl` | Configuration, index des animations, commandes, persistance des salons et orchestration | Parsing brut du protocole IRC ou détails TLS |
| `modules/TCL-PKG-IRCServices/ircservices.tcl` | Socket, protocole de liaison, dispatch des événements, création du pseudoclient | Règles métier propres à ClaraServ |
| `modules/TCL-ZCT/ZCT.tcl` | Couleurs IRC, substitutions textuelles et petites utilitaires | Réécriture de commandes globales de l’hôte |
| `db/database.*.db` | Catalogue déclaratif des animations | Code ou configuration secrète |
| `db/salon.db` | Liste des salons persistants | Mot de passe d’administration |

## Règles de robustesse mises en œuvre

La réception IRC est en mode non bloquant. Conformément au comportement documenté de `fileevent`, le gestionnaire vérifie l’état EOF après une tentative de lecture, évitant les réexécutions continues lorsque le pair ferme la connexion [3]. Un message IRC est traité comme une **chaîne** et découpé avec une expression régulière, jamais comme une liste Tcl. Ainsi, une accolade non appariée dans une commande utilisateur ne peut plus provoquer `unmatched open brace in list`.

Les animations sont indexées une fois au démarrage dans un `dict`, au lieu d’effectuer une recherche linéaire dans la base pour chaque message. Le catalogue est également validé : chaque animation doit posséder une commande commençant par `!`, une réponse de niveau `0` ou `1`, et aucune entrée ne peut être dupliquée. La gestion des salons utilise une comparaison littérale insensible à la casse, une validation de nom de canal et une réécriture temporaire suivie d’un renommage atomique.

## Migration recommandée

La migration peut être effectuée sans interrompre toutes les installations : testez d’abord le nouveau binaire sur un IRCD de préproduction, gardez Eggdrop pour l’instance existante, puis basculez l’un après l’autre les services après validation du lien serveur et des commandes. La compatibilité exacte dépend du protocole « server-to-server » de chaque IRCD ; les messages `PROTOCTL`, `SID`, `UID` et `SJOIN` actuellement produits sont orientés UnrealIRCd/TS6 et ne doivent pas être supposés universels.

```ini
# /etc/systemd/system/claraserv.service
[Unit]
Description=ClaraServ IRC animation service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=claraserv
WorkingDirectory=/opt/claraserv
ExecStart=/usr/bin/tclsh /opt/claraserv/ClaraServ.tcl
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/opt/claraserv/db

[Install]
WantedBy=multi-user.target
```

Après avoir créé `/opt/claraserv/ClaraServ.conf` avec des permissions `0600`, activez le service avec :

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now claraserv.service
sudo journalctl -u claraserv -f
```

## Évolutions recommandées

Les prochaines itérations doivent conserver la séparation actuelle. Une première amélioration utile serait une interface `Storage` permettant d’utiliser soit les fichiers actuels, soit SQLite dans une version ultérieure, sans modifier les commandes. Une seconde serait une couche `Auth` indépendante de l’IP ou d’un mot de passe transmis en message privé : compte IRC identifié, liste ACL de masques hôte, ou compte administrateur local avec empreinte de mot de passe.

Les commandes d’animation peuvent ensuite évoluer sans compromettre l’esprit du projet : `!search <mot>` pour rechercher une animation, `!alias <nom> <commande>` pour les synonymes administrés, `!stats` pour un classement local optionnel, et `!lang <fr|en>` pour un choix de catalogue par salon. Ces ajouts doivent être optionnels, accompagnés de tests et d’un mécanisme anti-inondation par utilisateur/salon.

## Références

[1] [Eggdrop — Tcl Commands](https://docs.eggheads.org/using/tcl-commands.html)

[2] [Tcl 8.6 — socket](https://www.tcl-lang.org/man/tcl8.6/TclCmd/socket.htm)

[3] [Tcl 8.6 — fileevent](https://www.tcl-lang.org/man/tcl8.6/TclCmd/fileevent.htm)
