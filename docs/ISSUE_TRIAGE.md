# Qualification des issues ouvertes

| Issue | Constat vérifié | Décision de traitement | Critère de clôture |
|---|---|---|---|
| #13 — Bug | Le rapport est une copie vierge du modèle ; ni version, ni environnement, ni comportement observé ne sont renseignés. | Fermer comme non reproductible / invalide. Les nouveaux formulaires empêchent désormais l’envoi sans éléments de diagnostic. | Commentaire expliquant les informations minimales nécessaires et clôture `not planned`. |
| #10 — Bug | L’erreur vise le gestionnaire historique `ClaraServ::Socket:Event`, supprimé par la révision `74f5c66`. L’issue ne précise ni version, ni ligne reçue, ni IRCD. | Corriger de manière préventive le parsing des messages dans le code actuel ; fermer l’ancien signalement, remplacé par l’architecture actuelle. | Tests unitaires du parseur avec accolades non appariées et commentaire précisant le périmètre. |
| #6 — Modèles d’issues | Les deux modèles actuels sont monolithiques et bilingues ; il manque le sélecteur demandé ainsi que des modèles FR/EN distincts. | Réaliser quatre formulaires GitHub (bogue / évolution en français et en anglais) et un fichier de configuration du sélecteur. | Présence des formulaires, champs obligatoires et liens README actualisés. |
| #5 — EvaServ | L’issue ne comporte aucune spécification ; la branche associée ne contient aucun commit additionnel ni code EvaServ. | Fermer comme non planifiée, afin d’éviter une implémentation spéculative. Ouvrir ultérieurement une issue dédiée avec objectif, IRCD cible, protocoles et critères d’acceptation. | Commentaire de clôture expliquant le manque de périmètre. |

> Cette qualification ne masque aucun défaut connu : elle sépare les anomalies reproductibles des demandes sans informations suffisantes. Les améliorations apportées au parseur et aux modèles d’issues réduisent directement le risque de récurrence.
