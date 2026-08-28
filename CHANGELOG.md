# Journal des changements

Ce fichier suit les changements fonctionnels et de maintenance de ClaraServ.

## 1.2.0 — 2026-08-28

Cette version transforme ClaraServ en application Tcl pouvant fonctionner sans Eggdrop, tout en préservant le chargement historique par Eggdrop.

| Domaine | Évolution |
|---|---|
| Exécution | Ajout de la boucle événementielle lors d’un démarrage direct avec `tclsh ClaraServ.tcl`. |
| Dépendances | Retrait de `logger` (tcllib) du module IRCServices ; suppression de la redéfinition globale de `putlog`. |
| Réseau | Socket IRC non bloquant, sortie UTF-8, erreurs de liaison journalisées sans arrêt brutal de la bibliothèque. |
| Parsing | Les messages IRC sont désormais traités comme du texte et non comme des listes Tcl. Une accolade non appariée ne peut plus déclencher `unmatched open brace in list`. |
| Configuration | Validation des booléens, du port, du salon de journalisation et du mot de passe d’exemple. |
| Animations | Index mémoire validé au démarrage, au lieu de recherches répétées dans le catalogue. |
| Salons | Validation du nom, égalité littérale et réécriture atomique de `salon.db`. |
| IRCD | Transmission de `serverinfo_descr` vers le message `SERVER`. |
| Qualité | Ajout d’une suite de régression Tcl autonome. |
| Contribution | Formulaires d’issues distincts FR/EN pour les bogues et les évolutions. |
| Documentation | Nouveau README, diagramme d’architecture et guide de développement. |

## Notes de migration

Les fichiers de configuration existants restent compatibles s’ils fournissent les clés documentées dans `ClaraServ.Example.conf`. Vérifiez que `admin_password` n’utilise pas la valeur d’exemple et exécutez `tclsh tests/test_claraserv.tcl` avant de redémarrer une instance.
