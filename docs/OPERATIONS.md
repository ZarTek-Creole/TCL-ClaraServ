# Exploitation ClaraServ

## Prérequis

- Tcl 8.6+
- TclTLS si `uplink_ssl 1`
- Modules vendored inclus dans le dépôt
- GNU Screen (optionnel) pour `bin/claraserv-screen start|attach`
- systemd (optionnel) pour la production

## Installation

```bash
git clone https://github.com/ZarTek-Creole/TCL-ClaraServ.git /opt/claraserv
cd /opt/claraserv
cp ClaraServ.Example.conf ClaraServ.conf
chmod 600 ClaraServ.conf
# Éditer ClaraServ.conf : remplacer tous les placeholders ; ne jamais committer
```

Vérifications hors réseau :

```bash
make check
make test
make test-local-process
```

Préflight structurel de la conf locale (aucune valeur affichée) :

```bash
make preflight-config
```

## Modes supportés

| Mode | Commande | Notes |
|---|---|---|
| Foreground | `tclsh ClaraServ.tcl` | Dev / diagnostic |
| screen | `bin/claraserv-screen …` | Ops/dev ; binaire `screen` requis pour start/attach |
| systemd | `systemd/claraserv.service` | Exemple versionné, **non** activé par le dépôt |

ClaraServ est un **service S2S** autonome en Tcl, pas un bot client.

## Chemins runtime

| Élément | Défaut | Configurable |
|---|---|---|
| Conf | `ClaraServ.conf` | `CLARASERV_CONF` / `--config` (lanceur) |
| Runtime dir | `<racine>/run` | `config(runtime_dir)` ; `CLARASERV_RUNTIME_DIR` / `--runtime-dir` |
| Instance | (vide) | `config(instance_name)` ou `--instance` → `run/<instance>/` |
| PID | `$runtime_dir/claraserv.pid` | via runtime dir |
| Stop file | `$runtime_dir/claraserv.stop` | via runtime dir |

Le contenu de `run/` n’est pas versionné (`run/.gitkeep` conserve le répertoire). Ne pas utiliser `/tmp` comme runtime de production.

**Multi-instances :** `instance_name` (`[A-Za-z0-9._-]{1,64}`) ou des `runtime_dir` distincts. Sans isolation, deux processus partagent le même stop-file.

## Foreground

```bash
cd /opt/claraserv
tclsh ClaraServ.tcl
```

Arrêt propre :

```bash
touch run/claraserv.stop
# ou : touch run/<instance>/claraserv.stop
```

Exit attendu : `0`. Un stop-file résiduel au prochain démarrage est consommé/supprimé au boot.

## Codes de sortie

| Situation | Code | Effet systemd typique |
|---|---|---|
| Stop-file / arrêt volontaire | `0` | pas de restart (`Restart=on-failure`) |
| Erreur conf / init | non zéro | restart possible |
| EOF S2S inattendu | `1` | restart attendu |
| SIGTERM sans Tclx | non garanti | après `TimeoutStopSec` : arrêt OS |
| Crash Tcl | non zéro | restart |

Sans Tclx, SIGTERM n’est pas un trap Tcl gracieux. Tclx n’est jamais obligatoire : l’arrêt recommandé reste le **stop-file**.

## Script `bin/claraserv-screen`

```bash
bin/claraserv-screen --help
bin/claraserv-screen --dry-run status
bin/claraserv-screen start
bin/claraserv-screen stop
bin/claraserv-screen restart
bin/claraserv-screen status
bin/claraserv-screen attach    # alias : join
bin/claraserv-screen logs
bin/claraserv-screen foreground
bin/claraserv-screen --instance lab start
```

Garanties : `set -Eeuo pipefail`, pas d’`eval`, validation des arguments, protection double instance, arrêt gracieux (stop-file) puis timeout, SIGKILL seulement avec `--force` ou `CLARASERV_ALLOW_SIGKILL=1`, `--dry-run` sans effet de bord. `status` : 0 actif, 1 inactif, 2 usage/environnement.

Validation locale (sans session réelle) : `make verify-screen`.

**Sessions screen réelles : NOT_TESTED** par les cibles Make du dépôt. Cursor ne lance pas Screen.

## systemd (exemple)

Fichiers : `systemd/claraserv.service`, `systemd/claraserv.env.example` (optionnel, sans secret).

Points clés de l’unité :

- `Type=simple`, utilisateur non-root `claraserv`
- chemins placeholders `/opt/claraserv`, runtime `/var/lib/claraserv/run`
- `ExecStart` absolu sans shell ; `ExecStop` = `touch …/claraserv.stop` ; `TimeoutStopSec=25`
- `Restart=on-failure`, `RestartSec=5`
- hardening : `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=full`, `ProtectHome`, `ReadWritePaths`
- aucun secret dans l’unit versionnée

Validation syntaxe : `make verify-systemd` (`systemd-analyze verify` si présent).

### Déploiement manuel (documentation uniquement — ne pas exécuter sans validation humaine)

```bash
sudo install -d -m 0755 /opt/claraserv
sudo install -d -m 0750 /etc/claraserv
sudo install -d -m 0750 /var/lib/claraserv/run
sudo useradd --system --home-dir /var/lib/claraserv --shell /usr/sbin/nologin claraserv || true
# Copier sources + ClaraServ.conf 0600
sudo install -m 0644 systemd/claraserv.service /etc/systemd/system/claraserv.service
# Personnaliser chemins / utilisateur, puis :
# sudo systemctl daemon-reload && sudo systemctl enable --now claraserv.service
# sudo journalctl -u claraserv.service -f
```

Aligner `config(runtime_dir)` / `instance_name` avec le chemin du stop-file de l’unit.

**Activation systemd réelle : NOT_TESTED** / interdite sans confirmation humaine. Cursor n’installe ni ne démarre d’unité.

## Logs

- Foreground / screen : stderr (niveaux ClaraServ).
- systemd : journald (`journalctl -u claraserv`).
- Ne jamais activer `uplink_debug` en production (fuite possible de `PASS`). Voir [SECURITY.md](SECURITY.md).

## Test process local (hors IRCd)

```bash
make test-local-process
```

Harness `tests/harness_local_process.tcl` : `disableAutoStart`, runtime temporaire, stop-file réel. **Ne valide pas** S2S ni un IRCd réel.

## Erreurs courantes

| Symptôme | Piste |
|---|---|
| Conf manquante / invalide | Copier Example, clés requises, pas de MDP exemple |
| Auth S2S refusée | Cohérence password / nom / SID / port / TLS avec l’IRCd |
| « wrong version number » TLS | Port plain vs TLS, `uplink_ssl` |
| Process reste après stop | Vérifier le bon `runtime_dir` / instance ; attendre le poll 500 ms |
| Restart en boucle | EOF S2S (exit 1) ou conf invalide — corriger avant de relancer |

Liaison UnrealIRCd : [UNREALIRCD.md](UNREALIRCD.md).

## Rollback

1. Arrêter : `bin/claraserv-screen stop` ou stop-file / `systemctl stop` si activé.
2. Restaurer commit et/ou `ClaraServ.conf` précédente.
3. Si conf IRCd modifiée : restaurer + `configtest` + rehash admin.
4. Rotation du mot de passe de lien si exposé.

## Procédures non exécutées par Cursor

- Installation de paquets, Screen, Tclx
- `systemctl enable/start`, copie vers `/etc/systemd/system`
- Connexion IRCd / rehash UnrealIRCd
- Commit / push / purge d’historique Git

## Limites non testées ici

- Session GNU Screen réelle
- Installation / activation systemd réelle
- Liaison S2S sur IRCd réel
- Trap SIGTERM via Tclx (si package absent)
