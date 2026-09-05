# Liaison S2S UnrealIRCd ↔ ClaraServ

Guide labo / préparation. **Aucun** IP, hostname, mot de passe, SID ou port de production dans ce document — placeholders uniquement.

Statut général : la syntaxe `link` / `listen` dépend de la **version exacte** d’UnrealIRCd. Valider avec `configtest` avant tout rehash.

## Prérequis

- ClaraServ autonome (`tclsh`) + `ClaraServ.conf` locale `0600`
- UnrealIRCd avec listener **serversonly** (TLS recommandé)
- Mot de passe de lien de **test** distinct de la production
- Sauvegarde de la conf IRCd + plan de rollback
- GO humain avant toute connexion réelle

Placeholders :

| Placeholder | Sens |
|---|---|
| `<IRCD_HOST>` | Hôte d’écoute / joignabilité |
| `<IRCD_S2S_TLS_PORT>` | Port listener TLS serversonly |
| `<CLARASERV_SERVICE_NAME>` | Nom serveur (== link == ulines == `serverinfo_name`) |
| `<CLARASERV_SERVICE_SID>` | SID TS6 `[0-9][0-9A-Z]{2}` |
| `<S2S_LINK_PASSWORD>` | Mot de passe de lien (jamais versionné) |
| `<SERVER_CERT_PATH>` / `<CA_FILE>` | Cert / CA côté ops IRCd |
| `<SERVICE_RUNTIME_USER>` | Utilisateur runtime ClaraServ |

## Cohérence obligatoire

- `link` name == ULine == `serverinfo_name` == `<CLARASERV_SERVICE_NAME>`
- SID unique et valide
- `uplink_host` / `uplink_port` joignables ; port numérique == listener
- `uplink_ssl 1` si listener TLS
- Même mot de passe des deux côtés, hors Git
- `uplink_debug 0`

## Côté ClaraServ (rappel)

Dans `ClaraServ.conf` (locale) : `uplink_*`, `serverinfo_name`, `serverinfo_id`, identité service. Préflight :

```bash
make preflight-config
```

N’affiche aucune valeur. Corrige localement les FAIL (placeholders, port, debug, SID).

## Comportement observé dans le code

| Domaine | Observation |
|---|---|
| Transport | `socket` ou `tls::socket` ; TLS via préfixe `+` sur le port |
| TLS peer | `-require 0 -request 0` (pas de validation CA client) |
| Auth | `PASS` puis PROTOCTL / SERVER / EOS |
| Identité | `serverinfo_name`, SID, `service_host` |
| EOF | `Request:Shutdown eof-unexpected 1` |
| Arrêt volontaire | quit/disconnect + exit 0 |

Dialecte PROTOCTL/UID/SJOIN orienté Unreal/TS6. Pas de changement de protocole sans incompatibilité prouvée + tests.

## Exemple de blocs IRCd (à adapter / commenter)

### Variante A — même hôte (loopback)

```irc
# listen <IRCD_HOST>:<IRCD_S2S_TLS_PORT> {
#     options { serversonly; tls; };
# };
#
# ulines {
#     <CLARASERV_SERVICE_NAME>;
# };
#
# # Style moderne (souvent Unreal 5/6) — À VALIDER sur votre version :
# link <CLARASERV_SERVICE_NAME> {
#     incoming {
#         mask *@<IRCD_HOST>;
#     }
#     password "<S2S_LINK_PASSWORD>";
#     class servers;
#     # options { tls; }
# };
```

Style historique (souvent 3.x) : blocs `password-connect` / `password-receive` — ne pas mélanger avec la syntaxe moderne ; valider sur la version réelle.

### Variante B — hôtes distincts

Identique à A, avec `<IRCD_HOST>` joignable, pare-feu source ClaraServ → port S2S uniquement, masks plus stricts, certificats selon politique réseau.

## Checklist (sans secret)

1. Version Unreal connue (`unrealircd --version`, anonymisée).
2. Sauvegarde conf IRCd.
3. Blocs adaptés + `configtest` (ou équivalent version) **PASS**.
4. Rehash seulement après configtest + GO.
5. ClaraServ : préflight PASS, `uplink_debug=0`, conf 0600.
6. Démarrage foreground : `tclsh ClaraServ.tcl`.
7. Observer : pas d’`ERROR :Closing Link` auth, présence service/SID, PING/PONG, commandes salon labo.
8. Arrêt : `touch run/claraserv.stop`.
9. Logs expurgés uniquement.

## Diagnostics

| Symptôme | Piste |
|---|---|
| Authentication failed | Password / nom link / ULine |
| Closing Link / version SSL | Port plain vs TLS |
| Collision SID | Autre serveur avec le même SID |
| Service invisible | ULine / EOS / UID |

## Rollback

1. Stop-file ClaraServ.
2. Restaurer conf IRCd ; configtest ; rehash admin.
3. Rotation `<S2S_LINK_PASSWORD>` si exposé.
4. Nettoyer artefacts locaux ; ne pas coller de logs bruts dans Git.

## Limites

- UnrealIRCd absent de nombreux hôtes de développement → **VALIDATION_UNREALIRCD_REQUISE**.
- InspIRCd / autres : hors scope sans labo dédié.
- Connexion réelle interdite sans demande humaine explicite.
