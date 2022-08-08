<span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
[![CC BY 4.0][cc-by-shield]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg

- [A propos](#a-propos)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [Téléchargement](#téléchargement)
  - [Configuration de l'eggdrop](#configuration-de-leggdrop)
  - [Configuration de ClaraServ Service](#configuration-de-claraserv-service)
  - [Configuration de votre IRCD (UnrealIRCd 5 et +)](#configuration-de-votre-ircd-unrealircd-5-et-)
    - [Comment créer un link ClaraServ sur UnrealIRCd](#comment-créer-un-link-claraserv-sur-unrealircd)
      - [Port dédié](#port-dédié)
      - [Ou Mono Port](#ou-mono-port)
      - [Ajoutez la uline](#ajoutez-la-uline)
      - [Ajoutez le link](#ajoutez-le-link)
    - [Comment créer un link ClaraServ sur UnrealIRCd](#comment-créer-un-link-claraserv-sur-unrealircd-1)
    - [Ajoutez le link](#ajoutez-le-link-1)
  - [Rehashez votre eggdrop](#rehashez-votre-eggdrop)
- [Resolution de probléme](#resolution-de-probléme)
  - [Debug Link](#debug-link)
  - [Probléme connu](#probléme-connu)
- [Utilisation](#utilisation)
- [Contribuer ou aider ce le projet ClaraServ](#contribuer-ou-aider-ce-le-projet-claraserv)
  - [Ameliorer le code](#ameliorer-le-code)
  - [Signaler un probleme](#signaler-un-probleme)
  - [Donation](#donation)
  - [Contact](#contact)
    - [Tickets](#tickets)
    - [IRC](#irc)
  - [Remerciements](#remerciements)

<!-- PROJECT LOGO -->
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
<details open="open">
  <summary>Table of Contents / Table des matières</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project / À propos du projet</a>
    </li>
    <li>
      <a href="#getting-started">Getting Started / Commencez</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites / Conditions préalables</a></li>
        <li><a href="#installation">Installation / Configuration</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage / Utilisation</a></li>
    <li><a href="#roadmap">Roadmap / Feuille de route</a></li>
    <li><a href="#contributing">Contributing / Contributions </a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgements">Acknowledgements /Remerciements</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
# A propos
Service IRC d'animation de salon, vos utilisateurs peuvent taper des commandes sur IRC qui fait reagir le services en créant une action à eux-même ou a un autre utilisateur

<!-- GETTING STARTED -->

# Prerequisites
* [eggdrop (v1.9+)](http://www.eggheads.org/)
* Serveur IRCD: [UnrealIRCd](https://www.unrealircd.org/), [InspIRCd](https://www.inspircd.org/) (Compatible avec les anciens et nouveau protocol/version)
* [Package IRCServices (v0.0.1+)](github.com/ZarTek-Creole/TCL-PKG-IRCServices)
* [Client GIT](https://git-scm.com/)


# Installation
## Téléchargement
Première étape, téléchargez dans le repertoire scripts/ de votre eggdrop le code ClaraServ grace au [Client GIT](https://git-scm.com/)
<br />
<br />
Exemple pour ```/home/votre-dossier/eggdrop/scripts/ClaraServ```
```
git clone https://github.com/ZarTek-Creole/TCL-Clara-Service /home/votre-dossier/eggdrop/scripts/ClaraServ
```
## Configuration de l'eggdrop
Deuxième étape, ouvrez le fichier de configuration de votre eggdrop ```eggdrop.conf``` et ajoutez la ligne ci-dessous :
```
source /home/votre-dossier/eggdrop/scripts/ClaraServ/ClaraServ.tcl
```

## Configuration de ClaraServ Service
Troisième étape, renommez le fichier ```ClaraServ.example.conf``` en ```ClaraServ.conf```,
éditez-le et configurez celui-ci en fonction de votre serveur IRCD

##  Configuration de votre IRCD (UnrealIRCd 5 et +)
Quatrième étape, il vous suffit de configurer le link dans votre fichier "unrealircd.conf" en fonction de la configuration que vous aurez réalisé dans "ClaraServ.conf". 

### Comment créer un link ClaraServ sur UnrealIRCd
Afin de réaliser votre link ClaraServ, veuillez vérifier si vous disposez d'un port dédié pour vos links ( plusieurs listen ) ou bien d'un mono port ( un seul listen ) :  

#### Port dédié 
```
listen IP-serveur:port-dedie {  
    options {  
		serversonly;  
	};  
};  
```  
####  Ou Mono Port 
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
Enregistrez le fichier de configuration. N'oubliez pas de _Rehash_ votre serveur.  
```/rehash```

### Comment créer un link ClaraServ sur UnrealIRCd

Afin de réaliser votre link Serveur ou Service, veuillez vérifier que vous disposez bien du _bind servers_ ci-dessous :  
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
 
Attention afin de réaliser votre link veuillez vérifier que votre configuration comporte bien le module ci dessous :  
```
<module name="m_spanningtree.so">
```
## Rehashez votre eggdrop
Cinquième étape, connectez-vous en party-line avec votre eggdrop puis tapez les deux commandes suivantes :
```
.rehash
```
ou redemarer votre eggdrop

# Resolution de probléme
## Debug Link
Si vous rencontrer un probleme a la liaison de votre ClaraServ vers votre IRCD activer le mode "débug"
Pour activer le mode *débug* changez la valeur ```set config(uplink_debug)``` dans ```ClaraServ.conf``` en mettant 1 a la place de 0.

## Probléme connu
Voir les [problèmes en suspens](github.com/ZarTek-Creole/TCL-Clara-Service/issues) pour une liste des fonctionnalités proposées (et des problèmes connus).

# Utilisation



# Contribuer ou aider ce le projet ClaraServ

## Ameliorer le code
Les contributions sont ce qui fait de la communauté open source un endroit incroyable pour apprendre, inspirer et créer. Toute contribution que vous apportez est ** grandement appréciée **.
1. Forkez le projet
2. Créez votre branche de fonctionnalités (`git checkout -b feature/AmazingFeature`)
3. Validez vos modifications (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une [Pull Request](github.com/ZarTek-Creole/TCL-Clara-Service/pulls)

## Signaler un probleme
Vous pouvez [signaler](github.com/ZarTek-Creole/TCL-Clara-Service/issues) un probleme

## Donation
Ce projet est partager librement et est entierement gratuit. Il à été developper durant le temps libre de l'auteur.
Le developemment a necesité de nombreuse heure, d'un serveur, etc

Le support est également totalement gratuit, la seul maniere deremercier l'auteur et permettre le suivi du code et de nouveau projet sont [les donations](https://github.com/ZarTek-Creole/DONATE), toute sommes même les plus minime sont **utile**

<!-- CONTACT -->
## Contact

ZarTek - [@ZarTek](github.com/ZarTek-Creole)

Lien du projet: [github.com/ZarTek-Creole/TCL-Clara-Service](github.com/ZarTek-Creole/TCL-Clara-Service)

### Tickets
Signalez tout bogues, toutes idées :
* [Creez un ticket]([#4-configuration-de-unrealircd](github.com/ZarTek-Creole/TCL-Clara-Service/issues))

### IRC
Vous pouvez me contacter sur IRC :

   * [irc.Extra-Cool.Fr 6667 #Zartek](irc://irc.Extra-Cool.Fr:6667/#Zartek)
   * [irc.Extra-Cool.Fr +6697 #Zartek](irc://irc.Extra-Cool.Fr:+6697/#Zartek)

## Remerciements
* Amandine de eggdrop.Fr pour son aide/idées/testes/..
* MenzAgitat car dans mes developpements il y a toujours des astuces/maniere de faire fournis par MenzAgitat ou bout code de MenzAgitat
* A tout les [donateurs](https://github.com/ZarTek-Creole/DONATE) et [donatrices](https://github.com/ZarTek-Creole/DONATE) qui font vivre [les projets](https://github.com/ZarTek-Creole/)
* A toutes les personnes qui propose des idées, signales des bogues, contribuent aux projets



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
