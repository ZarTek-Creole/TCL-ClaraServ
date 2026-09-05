# Sécurité ClaraServ

## Principes

- Ne jamais versionner `ClaraServ.conf`, mots de passe uplink/admin, certificats privés, tokens.
- Ne jamais journaliser de valeurs de secrets (stderr, journald, tickets, chat).
- Les secrets ne passent **pas** par arguments shell du lanceur (pas d’`Environment=` de mot de passe dans l’unit versionnée).
- **`uplink_debug=1` est dangereux** : IRCServices peut journaliser chaque `send` (dont `PASS`). Labo court uniquement, puis remettre à `0`.
- `.gitignore` protège les **nouveaux** fichiers non suivis ; un fichier **déjà suivi** reste dans Git même s’il figure dans `.gitignore`.
- Les exemples versionnés n’utilisent que des placeholders fictifs (jamais d’IP, SID, port ou mot de passe réels).

## Fichiers sensibles

| Fichier | Statut | Règle |
|---|---|---|
| `ClaraServ.conf` | gitignoré, local | Créer depuis Example ; `chmod 600` ; ne pas committer |
| `ClaraServ.Example.conf` | versionné | Placeholders / valeurs fictives uniquement |
| `eggdrop.conf` | **retiré** de la branche de travail | Ancien hôte legacy ; peut rester dans l’**historique Git** ; rotation obligatoire ; pas de purge d’historique ici |
| `db/salon.db` | gitignoré | Runtime |
| `*.pid`, `run/*`, `logs/`, `.env` | gitignorés | Runtime |
| Unit systemd versionnée | sans secret | Secrets hors unit (`ClaraServ.conf` ou EnvironmentFile local 0600) |

## Retrait de `eggdrop.conf`

ClaraServ n’utilise plus Eggdrop. Le fichier `eggdrop.conf` a été **supprimé de la branche de travail** (et de l’index). `.gitignore` contient `eggdrop.conf` comme protection future.

Limites :

- L’historique Git peut encore contenir ce fichier et d’éventuels secrets.
- Aucune purge d’historique n’a été effectuée (décision distincte, hors scope).
- Toute valeur historiquement exposée doit être considérée compromise → **rotation**.

## Rotation

Si un secret a pu être exposé (dépôt, ticket, log debug, historique Git, copie d’écran) :

1. Le considérer compromis.
2. Générer un nouveau secret côté IRCd **et** ClaraServ.
3. Mettre à jour uniquement les fichiers locaux non versionnés.
4. Ne pas committer l’ancien ni le nouveau secret.

## Permissions et compte

- Conf : `0600`, propriétaire = utilisateur du service.
- Répertoires runtime / db : droits restrictifs (`0750` typique).
- Utilisateur de service **non-root**.
- Production : chemins dédiés (`/opt/claraserv`, `/etc/claraserv`, …).

## TLS

- ClaraServ active TLS si `uplink_ssl 1` (`tls::socket`).
- Options actuelles IRCServices : `-require 0 -request 0` (pas de validation CA client).
- Activer une validation stricte de pair/certificat seulement après **décision d’exploitation** documentée.
- Pare-feu : n’ouvrir le port S2S qu’aux sources nécessaires.

## Protocole S2S

- Mot de passe de lien distinct labo / production.
- Cohérence exacte nom link / ULine / `serverinfo_name` / SID / port / TLS.
- Ne pas coller de conf IRCd de production dans Git ou la doc.

## Environnements

| Environnement | Règle |
|---|---|
| Tests `make test*` | Hors réseau IRCd, sans conf réelle, sans secret |
| Labo S2S | Placeholders remplacés localement ; validation humaine avant connexion |
| Production | Conf 0600, debug off, utilisateur non-root, secrets hors Git |

## Responsabilité de l’administrateur

L’opérateur reste responsable de la rotation des secrets, du durcissement TLS, du pare-feu, des permissions fichiers, et de ne jamais publier de conf réelle. ClaraServ fournit des garde-fous (gitignore, placeholders, logs sans valeurs) — pas une garantie opérationnelle complète.

## Divulgation de logs

Fournir uniquement des extraits **expurgés** (pas de `PASS`, password, SID réel, IP sensible si politique l’exige). Préférer messages d’erreur génériques et codes de sortie.
