# Exploitation ClaraServ

## Prérequis

- Tcl 8.6+
- TclTLS si `uplink_ssl 1`
- Modules vendored inclus dans le dépôt
- GNU Screen (optionnel) pour `bin/claraserv-screen`
- systemd (optionnel) pour la production

## Installation

```bash
git clone https://github.com/ZarTek-Creole/TCL-ClaraServ.git /opt/claraserv
cd /opt/claraserv
cp ClaraServ.Example.conf ClaraServ.conf
chmod 600 ClaraServ.conf
# Éditer ClaraServ.conf : remplacer tous les placeholders ; ne jamais committer
```

```bash
make check
make test
```

## Modes

| Mode | Commande |
|---|---|
| Foreground | `tclsh ClaraServ.tcl` |
| screen | `bin/claraserv-screen …` |
| systemd | exemple `systemd/claraserv.service` (**non** activé par le dépôt) |

## Chemins runtime

| Élément | Défaut | Configurable |
|---|---|---|
| Conf | `ClaraServ.conf` | locale uniquement (gitignore) |
| Runtime dir | `<racine>/run` | `config(runtime_dir)` / `CLARASERV_RUNTIME_DIR` |
| Instance | (vide) | `config(instance_name)` → `run/<instance>/` |
| PID / stop | `$runtime_dir/claraserv.pid` / `.stop` | via runtime dir |

Le répertoire `run/` est créé au démarrage (non versionné). Ne pas utiliser `/tmp` en production.

## Foreground

```bash
tclsh ClaraServ.tcl
touch run/claraserv.stop   # arrêt propre → exit 0
```

## Codes de sortie

| Situation | Code | systemd (`Restart=on-failure`) |
|---|---|---|
| Stop-file / arrêt volontaire | `0` | pas de restart |
| Erreur conf / init | non zéro | restart possible |
| EOF S2S inattendu | `1` | restart attendu |

Sans Tclx, SIGTERM n’est pas un trap Tcl : préférer le **stop-file**.

## `bin/claraserv-screen`

```bash
bin/claraserv-screen --help
bin/claraserv-screen --dry-run status
bin/claraserv-screen start|stop|restart|status|attach|logs|foreground
bin/claraserv-screen --instance lab start
```

## systemd (exemple)

Fichiers : `systemd/claraserv.service`, `systemd/claraserv.env.example` (sans secret).

- `Type=simple`, user non-root, chemins `/opt/claraserv`, runtime `/var/lib/claraserv/run`
- `ExecStop` = `touch …/claraserv.stop` ; `TimeoutStopSec=25` ; `Restart=on-failure`
- Validation syntaxe : `make verify-systemd` (si `systemd-analyze` présent)

Ne pas `enable`/`start` sans validation humaine. Aligner `config(runtime_dir)` avec l’unit.

## Logs

Foreground/screen → stderr ; systemd → journald. Jamais `uplink_debug=1` en production ([SECURITY.md](SECURITY.md)).

## Salon public vs `service_chanmodes`

Appliqué sur `service_channel` à l’EOS **si non vide**.

| Valeur | Usage |
|---|---|
| `""` (défaut Example) | Recommandé pour salon d’accueil / animations public |
| `+nt` | Acceptable sur salon public |
| `+Osnt` | **+O = IRCops only** — logs/services uniquement, **jamais** un accueil public |

Avec `+O`, Kiwi / users non-oper reçoivent `520 (IRCops only)`.

## Erreurs courantes

| Symptôme | Piste |
|---|---|
| Conf manquante / invalide | Example → conf, pas de placeholder / MDP d’exemple |
| Auth S2S refusée | password / nom / SID / port / TLS |
| wrong version number TLS | port plain vs TLS, `uplink_ssl` |
| Process reste après stop | mauvais `runtime_dir` / instance |
| Restart en boucle | EOF S2S (exit 1) ou conf invalide |

S2S Unreal : [UNREALIRCD.md](UNREALIRCD.md).

## Rollback

1. Stop-file / `bin/claraserv-screen stop` / `systemctl stop`
2. Restaurer commit et/ou `ClaraServ.conf`
3. Si conf IRCd modifiée : restaurer + `configtest` + rehash
4. Rotation du mot de passe de lien si exposé

## Limites

- Session Screen réelle, activation systemd réelle, S2S sur IRCd réel : hors `make` (labo / ops)
- Trap SIGTERM via Tclx : seulement si le package est installé
