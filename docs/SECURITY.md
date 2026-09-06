# Sécurité ClaraServ

## Principes

- Ne jamais versionner `ClaraServ.conf`, mots de passe uplink/admin, certificats privés, tokens.
- Ne jamais journaliser de valeurs de secrets (stderr, journald, tickets).
- Pas de secrets dans l’unit systemd versionnée ni en arguments shell.
- **`uplink_debug=1` est dangereux** (trafic `send` dont `PASS` possible) — labo court uniquement, puis `0`.
- Exemples versionnés = placeholders fictifs uniquement.

## Fichiers sensibles

| Fichier | Statut | Règle |
|---|---|---|
| `ClaraServ.conf` | gitignoré | Depuis Example ; `chmod 600` |
| `ClaraServ.Example.conf` | versionné | Placeholders uniquement |
| `db/salon.db`, `run/*`, `*.pid`, `*.log`, `.env` | gitignorés | Runtime |
| `systemd/*.service` | versionné | Sans secret |

Un ancien `eggdrop.conf` peut exister dans l’**historique** Git (runtime Eggdrop abandonné). Secrets historiquement exposés → **rotation**. `.gitignore` bloque une réintroduction accidentelle.

## Rotation

1. Considérer le secret compromis.
2. Nouveau secret côté IRCd **et** ClaraServ (fichiers locaux non versionnés).
3. Ne committer ni l’ancien ni le nouveau.

## Permissions

- Conf `0600` ; runtime/db restrictifs ; utilisateur **non-root**.

## TLS / S2S

- `uplink_ssl 1` → `tls::socket` ; aujourd’hui `-require 0 -request 0` (pas de validation CA client).
- Cohérence link / ULine / `serverinfo_name` / SID / port / TLS / password.
- Pare-feu : port S2S limité aux sources nécessaires.

## Divulgation

Extraits de logs **expurgés** uniquement (pas de `PASS`, password, SID/IP sensibles).
