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
- [Prérequis](#prérequis)
- [Installation](#installation)
  - [Téléchargement](#téléchargement)
  - [Configuration de l’eggdrop](#configuration-de-leggdrop)
  - [Configuration de ClaraServ Service](#configuration-de-claraserv-service)
  - [Configuration de votre IRCD (UnrealIRCd 5 et +)](#configuration-de-votre-ircd-unrealircd-5-et-)
    - [Comment créer un link ClaraServ sur UnrealIRCd](#comment-créer-un-link-claraserv-sur-unrealircd)
      - [Port dédié](#port-dédié)
  - [Rehashez votre eggdrop](#rehashez-votre-eggdrop)
- [Les commandes de ClaraServ](#les-commandes-de-claraserv)
  - [En privé à ClaraServ](#en-privé-à-claraserv)
  - [En publique (sur un salon)](#en-publique-sur-un-salon)
- [Resolution de problèmes](#resolution-de-problèmes)
  - [Débug Link](#débug-link)
  - [Les problèmes connus](#les-problèmes-connus)
- [Utilisation](#utilisation)
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


# Prérequis
* [eggdrop (v1.9+)](http://www.eggheads.org/)
* Serveur IRCD : [UnrealIRCd](https://www.unrealircd.org/), [InspIRCd](https://www.inspircd.org/) (Compatible avec les anciens et nouvelles versions)
* [Package IRCServices (v0.0.1+)](github.com/ZarTek-Creole/TCL-PKG-IRCServices)
* [Client GIT](https://git-scm.com/)


# Installation
## Téléchargement
Première étape, téléchargez dans le répertoire scripts/ de votre eggdrop le code ClaraServ grâce au [Client GIT](https://git-scm.com/)
<br />
<br />
Exemple pour ```/home/votre-dossier/eggdrop/scripts/ClaraServ```
```
git clone https://github.com/ZarTek-Creole/TCL-Clara-Service /home/votre-dossier/eggdrop/scripts/ClaraServ
```
## Configuration de l’eggdrop
Deuxième étape, ouvrez le fichier de configuration de votre eggdrop ```eggdrop.conf``` et ajoutez la ligne ci-dessous :
```
source /home/votre-dossier/eggdrop/scripts/ClaraServ/ClaraServ.tcl
```

## Configuration de ClaraServ Service
Troisième étape, renommez le fichier ```ClaraServ.example.conf``` en ```ClaraServ.conf```,
éditez-le et configurez celui-ci en fonction de votre serveur IRCD

##  Configuration de votre IRCD (UnrealIRCd 5 et +)
Quatrième étape, il vous suffit de configurer le link dans votre fichier “unrealircd.conf” en fonction de la configuration que vous aurez réalisé dans “ClaraServ.conf”. 

### Comment créer un link ClaraServ sur UnrealIRCd
Afin de réaliser votre link ClaraServ, veuillez vérifier si vous disposez d’un port dédié pour vos links (plusieurs listen) ou bien d’un mono port (un seul listen) :  

#### Port dédié 
```
listen IP-serveur:port-dedie {  
    options {  
    serversonly;  
  };  
};  
```  
####  Ou Mono Port 
```
listen IP-serveur:mono-port;
```
  
#### Ajoutez la uline
```
ulines {  
ClaraServ.nom-de-domaine.fr;  
...  
...  
};
```
#### Ajoutez le link
```
link EvaServ.nom-de-domaine.fr {  
  username *;  
  hostname IP-link;  
  bind-ip *;  
  port Port-link;  
  hub *;  
  password-connect "mot-de-passe-link";  
  password-receive "mot-de-passe-link";  
  class servers;  
};
```
Enregistrez le fichier de configuration. N’oubliez pas de _Rehash_ votre serveur.  
```/rehash```

### Comment créer un link ClaraServ sur UnrealIRCd

Afin de réaliser votre link Serveur ou Service, veuillez vérifier que vous disposez bien du _bind serveur_ ci-dessous :  
```
 <bind address="IP-serveur" port="port-dedie" type="servers"> 
```
### Ajoutez le link
  
* Serveur 1  
```
  <link name="irc2.domaine.tld" ipaddr="10.0.0.2" port="7000" autoconnect="60" hidden="no" sendpass="mot-de-passe" recvpass="mot-de-passe">
``` 
* Serveur 2  
```
  <link name="irc1.domaine.tld" ipaddr="10.0.0.1" port="7000" hidden="no" sendpass="mot-de-passe" recvpass="mot-de-passe">
  ```

* Link Service  
```
<link name="EvaServ.domaine.tld" ipaddr="10.0.0.1" port="7000" allowmask="10.0.0.1" sendpass="mot-de-passe" recvpass="mot-de-passe">  

<uline server="Service.domaine.tld" silent="no">
```
 
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

# Les commandes de ClaraServ
ℹ️ Les informations entre <texte> sont obligatoire et ceux entre [texte] sont facultatif.
## En privé à ClaraServ
!help                    -   Affiche l'aide
!<commande> [Pseudonyme] -   Exécute une animation
!random     [Pseudonyme] -   Choisi une animation de manière aléatoire
!about                   -   Affiche des informations sur ClaraServ

## En publique (sur un salon)
# Resolution de problèmes
## Débug Link
Si vous rencontrez un problème à la liaison de votre ClaraServ vers votre IRCD, activer le mode “débug”
Pour activer le mode *débug* changez la valeur ```set config(uplink_debug)``` dans ```ClaraServ.conf``` en mettant 1 à la place de 0.

## Les problèmes connus
Voir les [problèmes en suspens](github.com/ZarTek-Creole/TCL-Clara-Service/issues) pour une liste des fonctionnalités proposées (et des problèmes connus).

# Utilisation



# Contribuer ou aider ce projet ClaraServ

## Améliorer le code
Les contributions sont ce qui fait de la communauté open source un endroit incroyable pour apprendre, inspirer et créer. Toute contribution que vous apportez est ** grandement appréciée **.
1. Forkez le projet
2. Créez votre branche de fonctionnalités (`git checkout -b feature/AmazingFeature`)
3. Validez vos modifications (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une [Pull Request](github.com/ZarTek-Creole/TCL-Clara-Service/pulls)

## Signaler un problème
Vous pouvez [signaler](github.com/ZarTek-Creole/TCL-Clara-Service/issues) un problème

## Donation
Ce projet est librement partagé et est entièrement gratuit. Il a été développé durant le temps libre de l’auteur.
Le développement a nécessité de nombreuse heure, d’un serveur, etc

Le support est également totalement gratuit, la seule manière de remercier l’auteur et permettre le suivi du code et de nouveau projet sont [les donations](https://github.com/ZarTek-Creole/DONATE), toutes sommes même les plus minimes sont **utiles**

## Contact

ZarTek - [@ZarTek](github.com/ZarTek-Creole)

Lien du projet : [github.com/ZarTek-Creole/TCL-Clara-Service](github.com/ZarTek-Creole/TCL-Clara-Service)

### Tickets
Signalez tout bogue, toutes idées :
* [Créez un ticket](github.com/ZarTek-Creole/TCL-Clara-Service/issues)

### IRC
Vous pouvez me contacter sur IRC :

   * [irc.Extra-Cool.Fr 6667 #Zartek](irc://irc.Extra-Cool.Fr:6667/#Zartek)
   * [irc.Extra-Cool.Fr +6697 #Zartek](irc://irc.Extra-Cool.Fr:+6697/#Zartek)

# Remerciements
* A Amandine d'eggdrop.Fr pour son aide/idées/testes/…
* A MenzAgitat car dans mes développements il y a toujours des astuces/manière de faire fournir par MenzAgitat ou bout code de MenzAgitat
* A tous les [donateurs](https://github.com/ZarTek-Creole/DONATE) et [donatrices](https://github.com/ZarTek-Creole/DONATE) qui font vivre [les projets](https://github.com/ZarTek-Creole/)
* A toutes les personnes qui proposent des idées, signalent des bogues, contribuent aux projets



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
