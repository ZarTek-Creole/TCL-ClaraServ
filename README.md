<span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
[![CC BY 4.0][cc-by-shield]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg

<br />
<p align="center">
  <a href="github.com/ZarTek-Creole/TCL-Clara-Service">
    <img src="https://upload.wikimedia.org/wikipedia/commons/6/6c/IRC_Logo_Small-01_%281%29.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">ClaraServ - IRC Service d'animation</h3>

  <p align="center">
    Service IRC "ClaraServ" en TCL pour EggDrop 🥚 🤖
    <br />
    <a href="https://github.com/ZarTek-Creole/TCL-ClaraServ/issues/new?assignees=&labels=bug&template=bug_report.md&title=Bug%3A+">Rapporter un bogue</a>
    ·
    <a href="https://github.com/ZarTek-Creole/TCL-ClaraServ/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=feature%3A+">Demander une fonctionalité
    ·
    <a href="https://github.com/ZarTek-Creole/TCL-Clara-Service/issues">Demander de l'aide</a>
  </p>
</p>

<!-- TABLE OF CONTENTS -->

- [À propos](#à-propos)
  - [Capture d'écran (screenshot)](#capture-décran-screenshot)
- [Installation & configuration](#installation--configuration)
  - [Prérequis](#prérequis)
  - [Téléchargement](#téléchargement)
  - [Configuration de votre EggDrop](#configuration-de-votre-eggdrop)
  - [Configuration de ClaraServ Service](#configuration-de-claraserv-service)
  - [Configuration de votre IRCD](#configuration-de-votre-ircd)
    - [Comment créer un link ClaraServ sur UnrealIRCd](#comment-créer-un-link-claraserv-sur-unrealircd)
      - [Block Listen](#block-listen)
      - [Block uline](#block-uline)
      - [Block link](#block-link)
    - [Comment créer un link ClaraServ sur InspIRCd](#comment-créer-un-link-claraserv-sur-inspircd)
      - [Block bind](#block-bind)
      - [Block link](#block-link-1)
      - [Block uline](#block-uline-1)
      - [Block module](#block-module)
  - [Rehashez votre EggDrop](#rehashez-votre-eggdrop)
- [Utilisation](#utilisation)
  - [Les commandes de ClaraServ](#les-commandes-de-claraserv)
    - [En privé (à ClaraServ)](#en-privé-à-claraserv)
    - [En publique (sur un salon)](#en-publique-sur-un-salon)
    - [les Animations (par defaut)](#les-animations-par-defaut)
  - [Les salons](#les-salons)
    - [Faire joindre ClaraServ](#faire-joindre-claraserv)
    - [Faire partir ClaraServ](#faire-partir-claraserv)
- [Un peu plus loin](#un-peu-plus-loin)
  - [Ajouter une nouvelle animation (!commande)](#ajouter-une-nouvelle-animation-commande)
  - [Les variables de ```substitutions```](#les-variables-de-substitutions)
- [Résolution de problèmes](#résolution-de-problèmes)
  - [Débug Link](#débug-link)
  - [Les problèmes connus](#les-problèmes-connus)
- [Contribuer ou aider ce projet ClaraServ](#contribuer-ou-aider-ce-projet-claraserv)
  - [Améliorer le code](#améliorer-le-code)
  - [Signaler un problème](#signaler-un-problème)
  - [Suggestions de fonctionalités](#sugestions-de-fonctionalités)
  - [Donation](#donation)
- [Contact](#contact)
  - [Tickets](#tickets)
  - [IRC](#irc)
- [ChangeLog](#changelog)
- [Remerciements](#remerciements)
- [Documentation pour les developpeurs](#documentation-pour-les-developpeurs)
# À propos
💡 Service IRC d’animation de salon, vos utilisateurs peuvent taper des commandes sur IRC qui fait réagir le service en créant une action à eux-mêmes ou à un autre utilisateur
## Capture d'écran (screenshot)
Car une image parle plus qu'une longue description :
![image](https://user-images.githubusercontent.com/11725850/183683409-a1022325-2bb6-436d-a4e6-5cb7b5bd1cca.png)
![image](https://user-images.githubusercontent.com/11725850/183684407-49359019-197f-4bea-82ba-1312c5ce6691.png)

# Installation & configuration
## Prérequis
* [EggDrop (v1.9+)](http://www.eggheads.org/)
* Serveur IRCD : [UnrealIRCd](https://www.unrealircd.org/), [InspIRCd](https://www.inspircd.org/) (Compatible avec les anciens et nouvelles versions)
* [Package IRCServices (v0.0.1+)](https://github.com/ZarTek-Creole/TCL-PKG-IRCServices)
* [Client GIT](https://git-scm.com/)
## Téléchargement
Première étape, téléchargez dans le répertoire scripts/ de votre EggDrop le code ClaraServ grâce au [Client GIT](https://git-scm.com/).
<br />
<br />
Exemple pour ```/home/votre-dossier/eggdrop/scripts/ClaraServ```
```
git clone https://github.com/ZarTek-Creole/TCL-Clara-Service /home/votre-dossier/eggdrop/scripts/ClaraServ
```
## Configuration de votre EggDrop
Deuxième étape, ouvrez le fichier de configuration de votre EggDrop ```eggdrop.conf``` et ajoutez ✍️ la ligne ci-dessous :
```
source /home/votre-dossier/eggdrop/scripts/ClaraServ/ClaraServ.tcl
```

## Configuration de ClaraServ Service
Troisième étape, renommez le fichier ```ClaraServ.example.conf``` en ```ClaraServ.conf```,
éditez-le ✍️ et configurez celui-ci en fonction de votre serveur IRCD.


## Configuration de votre IRCD

Quatrième étape, il vous suffit de configurer le ” link ” ✍️ en fonction de la configuration que vous aurez réalisé dans **ClaraServ.conf**. 

### Comment créer un link ClaraServ sur UnrealIRCd
Afin de réaliser votre link ClaraServ, veuillez vérifier si vous disposez d’un port dédié pour vos links (plusieurs listen) ou bien d’un mono port (un seul listen) :  

#### Block Listen
```
listen <IP-serveur>:<Port-link> {  
  options {  
    serversonly;  # Pour les services seulement
		tls;          # Activer le SSL
  };  
};  
```
```<IP-serveur>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```<br />
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```<br />
Si vous spécifier ```tls;```, vous activer une connexion sécuriser en ```SSL```; La valeur de ```config(uplink_ssl)``` doit être mise à ```1```
 

#### Block uline
```
ulines {  
  <ClaraServ.nom-de-domaine.fr>;  
};
```
Ajoutez le nom de domaine (virtuel ou non) de votre link a la place de ```<ClaraServ.nom-de-domaine.fr>```, celui-ci doit être identique a la valeur ```config(service_host)``` du fichier ClaraServ.conf
#### Block link
```
link <ClaraServ.nom-de-domaine.fr> {  
  username          *;  
  hostname          <IP-link>;  
  bind-ip           *;  
  port              <Port-link>;  
  hub               *;  
  password-connect  "<mot-de-passe-link>";  
  password-receive  "<mot-de-passe-link>";  
  class servers;  
};
```
```<ClaraServ.nom-de-domaine.fr>``` doit être identique a la valeur ```config(service_host)``` du fichier ```ClaraServ.conf```<br />
```<mot-de-passe-link>``` doit être identique a la valeur ```config(uplink_password)``` du fichier ```ClaraServ.conf```<br />
```<IP-link>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```<br />
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```<br />

Enregistrez le fichier de configuration. N’oubliez pas de **Rehash** votre serveur.  
```/rehash```

### Comment créer un link ClaraServ sur InspIRCd
#### Block bind  
Afin de réaliser votre link Serveur ou Service, veuillez vérifier que vous disposez bien du *bind serveur* ci-dessous :  
```
 <bind address="<IP-link>" port="<Port-link>" type="servers"> 
```
```<IP-link>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```<br />
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```<br />
#### Block link  
```
<link name="<ClaraServ.nom-de-domaine.fr>" ipaddr="<IP-link>" port="<Port-link>" allowmask="<IP-link>" sendpass="<mot-de-passe-link>" recvpass="<mot-de-passe-link>">  
```
```<ClaraServ.nom-de-domaine.fr>``` doit être identique a la valeur ```config(service_host)``` du fichier ```ClaraServ.conf```<br />
```<mot-de-passe-link>``` doit être identique a la valeur ```config(uplink_password)``` du fichier ```ClaraServ.conf```<br />
```<IP-link>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```<br />
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```<br />
#### Block uline
```
<uline server="<ClaraServ.nom-de-domaine.fr>" silent="no">
```
 Ajoutez le nom de domaine (virtuel ou non) de votre link a la place de ```<ClaraServ.nom-de-domaine.fr>```, celui-ci doit être identique a la valeur ```config(service_host)``` du fichier ClaraServ.conf

 
#### Block module
Attention, dans le but de réaliser votre link, veuillez vérifier que votre configuration comporte bien le module ci-dessous : 
```
<module name="m_spanningtree.so">
```
## Rehashez votre EggDrop
Cinquième étape, connectez-vous en Party-Line avec votre EggDrop puis tapez la commande suivante :
```
.rehash
```
ou redémarrez votre EggDrop<br /><br />
Notez: évitez d'arrêter votre EggDrop autrement qu'avec la commande *.die* en partyline.<br />
En effet la commande *kill* peut endommager les bases de données en fichiers
# Utilisation
## Les commandes de ClaraServ
ℹ️ Les informations entre <texte> sont obligatoires et celles entre [texte] sont facultatives.
### En privé (à ClaraServ)
```/msg ClaraServ help```
**help**                                 -   Affiche cette aide
**cmds**                                 -   Affiche la liste des commandes
**about**                                -   A propos de ClaraServ
**join** <#Salon> <Mot_de_passe_admin>   -   Joindre le robot ClaraServ sur le <#Salon>
**part** <#Salon> <Mot_de_passe_admin>   -   Retiré le robot ClaraServ du <#Salon>

### En publique (sur un salon)
```/msg #Salon !help```
**!help**                                -   Affiche cette aide
**!cmds**                                -   Affiche la liste des commandes
**!<commande>** [Pseudonyme]             -   Exécute une animation
**!random**     [Pseudonyme]             -   Choisi une animation de manière aléatoire
**!about**                               -   A propos de ClaraServ
### les Animations (par defaut)
Liste exhautive
```
    !7up      |     !aime     |     !ange     |     !anni     |    !apéro     |    !baffe     |    !bière     |     !bjr     
   !boude     |    !bouge     |     !bus      |     !bye      |     !café     |   !carambar   |  !champagne   |    !chante   
  !chocolat   | !chocolatine  |    !choqué    |    !clope     |     !clé      |     !coca     |    !cochon    |    !coeur    
 !croissant   |    !curly     |    !câlin     |    !danse     |     !dodo     |    !dzoss     |     !eau      |   !embrasse  
   !fesses    |    !fessée    |    !fleur     |    !fouet     |    !gaufre    |    !glace     |    !gratte    |    !gâteau   
    !jump     |    !kebab     |     !kiss     |     !love     |     !lune     |    !macdo     |   !mariage    |     !mars    
  !massage    |    !merci     |  !milkshake   |     !mms      |    !mojito    |     !mord     |    !mouton    |     !noir    
   !oignon    |   !orangina   |    !patate    |    !pelle     |     !perf     |   !piscine    |    !pizza     |    !plouf    
  !popcorn    |    !pouet     |    !rateau    |   !redbull    |    !relou     |     !rhum     |     !rose     |   !ruisseau  
   !saute     |     !seau     |     !sexy     |    !string    |  !tendresse   |     !thé      |    !triste    |  !tropicana  
   !truite    |     !vent     |    !vidéo     |    !vittel    |     !vnr      |     !waff     |    !whisky    |     !zen     
   !écran     |    !étoile   
```
## Les salons
### Faire joindre ClaraServ
```
/msg ClaraServ join <#Salon> <Mot_de_passe_admin>
```
```<#Salon>``` remplacez par le nom du salon que ClaraServ doit joindre.<br />
```<Mot_de_passe_admin>``` remplacez par le mot de passe que vous avez defini dans ```ClaraServ.conf``` à la variable ```config(admin_password)```.

### Faire partir ClaraServ
```
/msg ClaraServ part <#Salon> <Mot_de_passe_admin>
```
```<#Salon>``` remplacez par le nom du salon que ClaraServ doit partir.<br />
```<Mot_de_passe_admin>``` remplacez par le mot de passe que vous avez defini dans ```ClaraServ.conf``` a la variable ```config(admin_password)```.

# Un peu plus loin
## Ajouter une nouvelle animation (!commande)
Pour ajouter une animation rendez-vous dans le répertoire db/, selectionnez le fichier dans la database.<langue>.db choisi avec ```config(db_lang)``` dans ```ClaraServ.conf```.
Suivis le schéma des autres animation en ajoutant :
```
	{{!<animation>}		{0}		{<Texte de l'animation>}}
	{{!<animation>}		{1}		{<Texte de l'animation>}}
```
```!<animation>``` est la commande pour lancer l'animation par exemple ```donation```<br />
La valeur ```{0}``` signifie "à soi-même", la personne fait l'animation à elle-même<br />
La valeur ```{1}``` signifie "moi à lui", la personne fait l'animation à quelqu'un<br />
```<Texte de l'animation>``` est le contenue de l'animation par exemple ```%sender% fait une donation au projet ClaraServ```<br />
ci-dessus remarqué ```%sender%``` qui est une variable de substitution.<br />

## Les variables de ```substitutions```
Les variables de substitutions permettent d'être remplacées une valeur précise (dans les bases de données d'animations).<br /><br />
```%pseudo%``` est remplacé par le ```pseudonyme``` à qui l'animation est *envoyé* (!animation ```pseudonyme```). <br />
```%sender%``` est remplacé par le ```pseudonyme``` de la personne qui *lance* l'animation.<br />
```%destination%``` est remplacé par le nom du ```#salon```.<br />
```%month%``` est remplacé par le nom du mois,  il sera remplacé par ```Janvier```<br />
```%month_num%``` est remplacé par le chiffre du mois, il sera remplacé par ```1```<br />
```%hour%``` est remplacé par le chiffre de l'heure, par exemple si il est 1h, il sera remplacé par ```01```<br />
```%hour_short%``` est remplacé par le chiffre de l'heure, par exemple si il est 1h, il sera remplacé par ```1```<br />
```%minutes%``` est remplacé par le chiffre de la minute actuelle, par exemple si il est 1h05, il sera remplacé par ```05```<br />
```%minutes_short%``` est remplacé par le chiffre de la minute actuelle, par exemple si il est 1h05, il sera remplacé par ```5```<br />
```%seconds%``` est remplacé par le chiffre de la seconde actuelle, par exemple si il est 1:05:09, il sera remplacé par ```09```<br />
```%seconds_short%``` est remplacé par le chiffre de la seconde actuelle, par exemple si il est 1:05:09, il sera remplacé par ```9```<br />
```%year%``` est remplacé par l'année sous la forme ```2022```<br />
```%day%``` est remplacé par le jour de la semaine par exemple ```mardi```<br />
```%day_num%``` est remplacé par le numéro du jour par exemple ```31```<br /><br />
Si vous avez besoin ou avez une idée de nouvelles variables de substitutions [suggérer ici](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues)

# Résolution de problèmes
## Débug Link
Si vous rencontrez un problème à la liaison de votre ClaraServ vers votre IRCD, activer le mode “débug”<br />
Pour activer le mode *débug* changez la valeur ```set config(uplink_debug)``` dans ```ClaraServ.conf``` en mettant ```1``` à la place de ```0```.

## Les problèmes connus
Voir les [problèmes en suspens](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues) pour une liste des fonctionnalités proposées (et des problèmes connus).

# Contribuer ou aider ce projet ClaraServ

## Améliorer le code
Les contributions sont ce qui fait de la communauté open source un endroit incroyable pour apprendre, inspirer et créer.
Toute contribution que vous apportez est **grandement appréciée**.
1. Forkez le projet
2. Créez votre branche de fonctionnalités (`git checkout -b feature/AmazingFeature`)
3. Validez vos modifications (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une [Pull Request](https://github.com/ZarTek-Creole/TCL-Clara-Service/pulls)

## Signaler un problème
👩‍🏭 Vous pouvez [signaler](https://github.com/ZarTek-Creole/TCL-ClaraServ/issues/new?assignees=&labels=bug&template=bug_report.md&title=Bug%3A+) un problème ⚠️

## Sugestions de fonctionalités
Vous pouvez faire des [Sugestions](https://github.com/ZarTek-Creole/TCL-ClaraServ/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=feature%3A+) d'idées 🧠

## Donation
Ce projet est librement partagé et est entièrement gratuit 💯🆓. 
Il a été développé durant le temps libre de l’auteur. 🕞 🕧 🕑<br />
Le développement a nécessité de nombreuses heure,s d’un serveur, etc<br /><br />
Le support est également totalement gratuit, la seule manière de remercier l’auteur et permettre le suivi du code et de nouveau projet sont [les donations](https://github.com/ZarTek-Creole/DONATE), toutes sommes même les plus minimes sont **utiles**

# Contact

* Auteur: ZarTek - [@ZarTek](https://github.com/ZarTek-Creole) 📬
* Lien du projet : [github.com/ZarTek-Creole/TCL-Clara-Service](https://github.com/ZarTek-Creole/TCL-Clara-Service)

## Tickets
Signalez tout bogue, toutes idées :
* [Créez un ticket](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues) ⛑️

## IRC
Vous pouvez me contacter sur IRC :

* [irc.Extra-Cool.Fr 6667 #Zartek](irc://irc.Extra-Cool.Fr:6667/#Zartek)
* [irc.Extra-Cool.Fr +6697 #Zartek](irc://irc.Extra-Cool.Fr:+6697/#Zartek)
# ChangeLog
Vous pouvez lire les modifications dans le [ChangeLog](ChangeLog.html) 🔖
# Remerciements
* A Amandine d'EggDrop.Fr pour son aide/idées/testes/…👍
* A [Maxime](https://www.extra-cool.fr) & [Tibs](https://www.Chatoo.fr) pour les emojis et les idées👍
* A MenzAgitat car dans mes développements il y a toujours des astuces/manière de faire fournir par MenzAgitat ou bout code de MenzAgitat👍
* A tous les [donateurs](https://github.com/ZarTek-Creole/DONATE) et [donatrices](https://github.com/ZarTek-Creole/DONATE) qui font vivre [les projets](https://github.com/ZarTek-Creole/) 💯 👍 🥇
* A toutes les (futures) personnes qui proposent des idées, signalent des bogues, contribuent aux projets!👍👍👍

# Documentation pour les developpeurs
[Documentation 📑](https://zartek-creole.github.io/TCL-ClaraServ/) 
<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/ZarTek/TCL-Clara-Service.svg?style=for-the-badge
[contributors-url]: github.com/ZarTek-Creole/TCL-Clara-Service/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/ZarTek/TCL-Clara-Service.svg?style=for-the-badge
[forks-url]: github.com/ZarTek-Creole/TCL-Clara-Service/network/members
[stars-shield]: https://img.shields.io/github/stars/ZarTek/TCL-Clara-Service.svg?style=for-the-badge
[stars-url]: github.com/ZarTek-Creole/TCL-Clara-Service/stargazers
[issues-shield]: https://img.shields.io/github/issues/ZarTek/TCL-Clara-Service.svg?style=for-the-badge
[issues-url]: github.com/ZarTek-Creole/TCL-Clara-Service/issues
[license-shield]: https://img.shields.io/github/license/ZarTek/TCL-Clara-Service.svg?style=for-the-badge
[license-url]: github.com/ZarTek-Creole/TCL-Clara-Service/blob/master/LICENSE.txt
[product-screenshot]: images/screenshot.png
