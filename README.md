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
    Service IRC "ClaraServ" en TCL pour Eggdrop
    <br />
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service/issues">Rapporter un bogue</a>
    ·
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service/issues">Demander une fonctionalitée
    ·
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service/issues">Demander de l'aide</a>
  </p>
</p>

<!-- TABLE OF CONTENTS -->

- [À propos](#à-propos)
  - [Capture d'écran (screenshot)](#capture-décran-screenshot)
- [Installation](#installation)
  - [Prérequis](#prérequis)
  - [Téléchargement](#téléchargement)
  - [Configuration de l’eggdrop](#configuration-de-leggdrop)
  - [Configuration de ClaraServ Service](#configuration-de-claraserv-service)
    - [Comment créer un link ClaraServ sur UnrealIRCd](#comment-créer-un-link-claraserv-sur-unrealircd)
      - [Block Listen](#block-listen)
      - [Block uline](#block-uline)
      - [Block link](#block-link)
    - [Comment créer un link ClaraServ sur InspIRCd](#comment-créer-un-link-claraserv-sur-inspircd)
      - [Block link](#block-link-1)
      - [Block link](#block-link-2)
      - [Block uline](#block-uline-1)
      - [Block module](#block-module)
  - [Rehashez votre eggdrop](#rehashez-votre-eggdrop)
- [Utilisation](#utilisation)
  - [Les commandes de ClaraServ](#les-commandes-de-claraserv)
    - [En privé (à ClaraServ)](#en-privé-à-claraserv)
    - [En publique (sur un salon)](#en-publique-sur-un-salon)
    - [les Animations (par defaut)](#les-animations-par-defaut)
- [Un peu plus loin](#un-peu-plus-loin)
  - [Ajouter une nouvelle animation (!commande)](#ajouter-une-nouvelle-animation-commande)
  - [Les variables de ```substitutions```](#les-variables-de-substitutions)
- [Résolution de problèmes](#résolution-de-problèmes)
  - [Débug Link](#débug-link)
  - [Les problèmes connus](#les-problèmes-connus)
- [Contribuer ou aider ce projet ClaraServ](#contribuer-ou-aider-ce-projet-claraserv)
  - [Améliorer le code](#améliorer-le-code)
  - [Signaler un problème](#signaler-un-problème)
  - [Donation](#donation)
- [Contact](#contact)
  - [Tickets](#tickets)
  - [IRC](#irc)
- [Remerciements](#remerciements)
# À propos
Service IRC d’animation de salon, vos utilisateurs peuvent taper des commandes sur IRC qui fait réagir le service en créant une action à eux-mêmes ou a un autre utilisateur
## Capture d'écran (screenshot)



# Installation
## Prérequis
* [eggdrop (v1.9+)](http://www.eggheads.org/)
* Serveur IRCD : [UnrealIRCd](https://www.unrealircd.org/), [InspIRCd](https://www.inspircd.org/) (Compatible avec les anciens et nouvelles versions)
* [Package IRCServices (v0.0.1+)](https://github.com/ZarTek-Creole/TCL-PKG-IRCServices)
* [Client GIT](https://git-scm.com/)
## Téléchargement
Première étape, téléchargez dans le répertoire scripts/ de votre eggdrop le code ClaraServ grâce au [Client GIT](https://git-scm.com/).
<br />
<br />
Exemple pour ```/home/votre-dossier/eggdrop/scripts/ClaraServ```
```
git clone https://github.com/ZarTek-Creole/TCL-Clara-Service /home/votre-dossier/eggdrop/scripts/ClaraServ
```
## Configuration de l’eggdrop
Deuxième étape, ouvrez le fichier de configuration de votre EggDrop ```eggdrop.conf``` et ajoutez la ligne ci-dessous :
```
source /home/votre-dossier/eggdrop/scripts/ClaraServ/ClaraServ.tcl
```

## Configuration de ClaraServ Service
Troisième étape, renommez le fichier ```ClaraServ.example.conf``` en ```ClaraServ.conf```,
éditez-le et configurez celui-ci en fonction de votre serveur IRCD.

## Configuration de votre IRCD (pour UnrealIRCd 5 et +)
Quatrième étape, il vous suffit de configurer le link dans votre fichier “unrealircd.conf” en fonction de la configuration que vous aurez réalisé dans “ClaraServ.conf”. 

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
```<IP-serveur>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```
Si vous spécifier ```tls;```, vous activer une connexion sécuriser en ```SSL```; La valeur de ```config(uplink_ssl)``` doit être mise à ```1```
config(uplink_host) 


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
```<ClaraServ.nom-de-domaine.fr>``` doit être identique a la valeur ```config(service_host)``` du fichier ```ClaraServ.conf```
```<mot-de-passe-link>``` doit être identique a la valeur ```config(uplink_password)``` du fichier ```ClaraServ.conf```
```<IP-link>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```

Enregistrez le fichier de configuration. N’oubliez pas de **Rehash** votre serveur.  
```/rehash```

### Comment créer un link ClaraServ sur InspIRCd
#### Block link  
Afin de réaliser votre link Serveur ou Service, veuillez vérifier que vous disposez bien du *bind serveur_*ci-dessous :  
```
 <bind address="<IP-link>" port="<Port-link>" type="servers"> 
```
```<IP-link>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```
#### Block link  
```
<link name="<ClaraServ.nom-de-domaine.fr>" ipaddr="<IP-link>" port="<Port-link>" allowmask="<IP-link>" sendpass="<mot-de-passe-link>" recvpass="<mot-de-passe-link>">  
```
```<ClaraServ.nom-de-domaine.fr>``` doit être identique a la valeur ```config(service_host)``` du fichier ```ClaraServ.conf```
```<mot-de-passe-link>``` doit être identique a la valeur ```config(uplink_password)``` du fichier ```ClaraServ.conf```
```<IP-link>``` doit être identique a la valeur ```config(uplink_host)``` du fichier ```ClaraServ.conf```
```<Port-link>``` doit être identique a la valeur ```config(uplink_port)``` du fichier ```ClaraServ.conf```
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
## Rehashez votre eggdrop
Cinquième étape, connectez-vous en Party-Line avec votre eggdrop puis tapez la commande suivante :
```
.rehash
```
ou redémarrer votre eggdrop
Notez: évitez d'areter votre EggDrop autre que *.die* en partyline -.
En effet la commande *kill* peut endomager les bases de données en fichiers
# Utilisation
## Les commandes de ClaraServ
ℹ️ Les informations entre <texte> sont obligatoire et ceux entre [texte] sont facultatif.
### En privé (à ClaraServ)
```/msg ClaraServ help```
help                                 -   Affiche cette aide
cmds                                 -   Affiche la liste des commandes
about                                -   A propos de ClaraServ
join <#Salon> <Mot_de_passe_admin>   -   Joindre le robot ClaraServ sur le <#Salon>
part <#Salon> <Mot_de_passe_admin>   -   Retiré le robot ClaraServ du <#Salon>

### En publique (sur un salon)
```/msg #Salon !help```
!help                                -   Affiche cette aide
!cmds                                -   Affiche la liste des commandes
!<commande> [Pseudonyme]             -   Exécute une animation
!random     [Pseudonyme]             -   Choisi une animation de manière aléatoire
!about                               -   A propos de ClaraServ
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
# Un peu plus loin
## Ajouter une nouvelle animation (!commande)
Pour ajouter une animation rendez-vous dans le répertoire db/, selectionnez le fichier dans la database.<langue>.db choisi avec ```config(db_lang)``` dans ```ClaraServ.conf```.
Suivis le schéma des autres animation en ajoutant :
```
	{{!<animation>}		{0}		{<Texte de l'animation>}}
	{{!<animation>}		{1}		{<Texte de l'animation>}}
```
```!<animation>``` est la commande pour lancer l'animation par exemple ```donation```
La valeur ```{0}``` signifie "à soi-même", la personne fait l'animation à elle-même
La valeur ```{1}``` signifie "moi à lui", la personne fait l'animation à quelqu'un
```<Texte de l'animation>``` est le contenue de l'animation par exemple ```%sender% fait une donation au projet ClaraServ```
ci-dessus remarqué ```%sender%``` qui est une variable de substitution.

## Les variables de ```substitutions```
Les variables de substitutions permet d'être remplacée une valeur précise (dans les bases de données d'animation).
```%pseudo%``` est remplacé par le ```pseudonyme``` à qui l'animation est *envoyé* (!animation ```pseudonyme```). 
```%sender%``` est remplacé par le ```pseudonyme``` de la personne *lance* l'animation.
```%destination%``` est remplacé par le nom du ```#salon```.
```%month%``` est remplacé par le nom du mois,  il sera remplacer par ``Janvier```
```%month_num%``` est remplacé par le chiffre du mois, il sera remplacer par ```1```
```%hour%``` est remplacé par le chiffre de l'heure, par exemple si il est 1h, il sera remplacer par ```01```
```%hour_short%``` est remplacé par le chiffre de l'heure, par exemple si il est 1h, il sera remplacer par ```1```
```%minutes%``` est remplacé par le chiffre de la minute actuel, par exemple si il est 1h05, il sera remplacer par ```05```
```%minutes_short%``` est remplacé par le chiffre de la minute actuel, par exemple si il est 1h05, il sera remplacer par ```5```
```%seconds%``` est remplacé par le chiffre de la secondes actuelle, par exemple si il est 1:05:09, il sera remplacer par ```09```
```%seconds_short%``` est remplacé par le chiffre de la secondes actuelle, par exemple si il est 1:05:09, il sera remplacer par ```9```
```%year%``` est remplacer par l'année sous la forme ```2022```
```%day%``` est remplacer par le jour de la semaine par exemple ```mardi```
```%day_num%``` est remplacer par le numero du jour par exemple ```31```
Si vous avez besoin ou avez une idée de nouvelles variables de substitutions [sugerer nous ici](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues)

# Résolution de problèmes
## Débug Link
Si vous rencontrez un problème à la liaison de votre ClaraServ vers votre IRCD, activer le mode “débug”
Pour activer le mode *débug* changez la valeur ```set config(uplink_debug)``` dans ```ClaraServ.conf``` en mettant ```1``` à la place de ```0```.

## Les problèmes connus
Voir les [problèmes en suspens](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues) pour une liste des fonctionnalités proposées (et des problèmes connus).





# Contribuer ou aider ce projet ClaraServ

## Améliorer le code
Les contributions sont ce qui fait de la communauté open source un endroit incroyable pour apprendre, inspirer et créer. Toute contribution que vous apportez est ** grandement appréciée **.
1. Forkez le projet
2. Créez votre branche de fonctionnalités (`git checkout -b feature/AmazingFeature`)
3. Validez vos modifications (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une [Pull Request](https://github.com/ZarTek-Creole/TCL-Clara-Service/pulls)

## Signaler un problème
Vous pouvez [signaler](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues) un problème

## Donation
Ce projet est librement partagé et est entièrement gratuit. Il a été développé durant le temps libre de l’auteur.
Le développement a nécessité de nombreuse heure, d’un serveur, etc

Le support est également totalement gratuit, la seule manière de remercier l’auteur et permettre le suivi du code et de nouveau projet sont [les donations](https://github.com/ZarTek-Creole/DONATE), toutes sommes même les plus minimes sont **utiles**

# Contact

ZarTek - [@ZarTek](https://github.com/ZarTek-Creole)

Lien du projet : [github.com/ZarTek-Creole/TCL-Clara-Service](https://github.com/ZarTek-Creole/TCL-Clara-Service)

## Tickets
Signalez tout bogue, toutes idées :
* [Créez un ticket](https://github.com/ZarTek-Creole/TCL-Clara-Service/issues)

## IRC
Vous pouvez me contacter sur IRC :

   * [irc.Extra-Cool.Fr 6667 #Zartek](irc://irc.Extra-Cool.Fr:6667/#Zartek)
   * [irc.Extra-Cool.Fr +6697 #Zartek](irc://irc.Extra-Cool.Fr:+6697/#Zartek)

# Remerciements
* A Amandine d'eggdrop.Fr pour son aide/idées/testes/…
* A Maxime & Tibs pour les emojis et les idées
* A MenzAgitat car dans mes développements il y a toujours des astuces/manière de faire fournir par MenzAgitat ou bout code de MenzAgitat
* A tous les [donateurs](https://github.com/ZarTek-Creole/DONATE) et [donatrices](https://github.com/ZarTek-Creole/DONATE) qui font vivre [les projets](https://github.com/ZarTek-Creole/)
* A toutes les (futures) personnes qui proposent des idées, signalent des bogues, contribuent aux projets!

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
