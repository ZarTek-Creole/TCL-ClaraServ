<span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
[![CC BY 4.0][cc-by-shield]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg



<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="github.com/ZarTek-Creole/TCL-Clara-Service">
    <img src="https://upload.wikimedia.org/wikipedia/commons/6/6c/IRC_Logo_Small-01_%281%29.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">ClaraServ - IRC Services</h3>

  <p align="center">
    Services IRC "ClaraServ" en TCL/Eggdrop
    <br />
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service"><strong>Explore the docs / Explorez les documents »</strong></a>
    <br />
    <br />
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service/issues">Report Bug</a>
    ·
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service/issues">Request Feature</a>
    ·
    <a href="github.com/ZarTek-Creole/TCL-Clara-Service/wiki">Wiki / Documenation</a>
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
## About The Project

IRC services in TCL - Trade show animation, Network help, User profile

----

Services IRC en TCL - Animation de salon, Aide de réseau, Profil d'utilisateur

<!-- GETTING STARTED -->
## Getting Started

This is an example of how you may give instructions on setting up your project locally.
To get a local copy up and running follow these simple example steps.

----
Voici un exemple de la manière dont vous pouvez donner des instructions sur la configuration de votre projet localement.
Pour obtenir une copie locale opérationnelle, suivez ces étapes simples d'exemple.

### Prerequisites
* [eggdrop (v1.9+)](http://www.eggheads.org/)
* [Unrealircd (v5.0+)](http://www.eggheads.org/)
* [Package IRCServices (v0.0.1+)](github.com/ZarTek-Creole/TCL-PKG-IRCServices)



### Installation
1.1.  Récuperez le code ClaraServ
Première étape, téléchargez le code, le mettre dans votre répertoire scripts/
Exemple pour ```/home/votre-dossier/eggdrop/scripts/ClaraServ```
```
git clone --recurse-submodules github.com/ZarTek-Creole/TCL-Clara-Service /home/votre-dossier/eggdrop/scripts/ClaraServ
```
ou 
```
wget github.com/ZarTek-Creole/TCL-Clara-Service/archive/refs/heads/main.zip -O ClaraServ.zip
unzip ClaraServ.zip -d /home/votre-dossier/eggdrop/scripts/ClaraServ
```
mettre a jour les sous modules (dependence) via git

```
git submodule update --init --recursive
```
1.2. Configuration de l'eggdrop
Deuxième étape, ouvrez le fichier de configuration de votre eggdrop ```eggdrop.conf``` et ajoutez la ligne ci-dessous :
```
source /home/votre-dossier/eggdrop/scripts/ClaraServ/ClaraServ.tcl
```

1.3.  Configuration de ClaraServ Service
Troisième étape, renommez le fichier ```ClaraServ.example.conf``` en ```ClaraServ.conf``` et configurez celui-ci en fonction de votre serveur IRC

1.4.  Configuration de votre IRCD (UnrealIRCd 5 et +)
Quatrième étape, il vous suffit de configurer le link dans votre fichier "unrealircd.conf" en fonction de la configuration que vous aurez réalisé dans "ClaraServ.conf". 

[Comment créer un link Service sur UnrealIRCd](http://www.exolia.fr/guide-lire-11.html)

1.5.  Rehashez votre eggdrop
Cinquième étape, connectez-vous en party-line avec votre eggdrop puis tapez les deux commandes suivantes :
```
.rehash
.ClaraServconnect
```

2. Un peu plus loin
2.1. Debug général
Si ClaraServ Service ne se connecte pas, activez le mode debug depuis la party-line  pour voir les erreurs directement dans le fichier "logs/ClaraServ.debug".
```
.ClaraServdebug on 
```
2.2. Debug Socket/Link
Pour activer le mode *socket debug* changez la valeur ```ClaraServ(sdebug)``` dans ```ClaraServ.conf``` en mettant 1 a la place de 0.
<!-- USAGE EXAMPLES -->
## Usage


Soon?

----

Bientôt

<!-- ROADMAP -->
## Roadmap

See the [open issues](github.com/ZarTek-Creole/TCL-Clara-Service/issues) for a list of proposed features (and known issues).

---
Voir les [problèmes en suspens](github.com/ZarTek-Creole/TCL-Clara-Service/issues) pour une liste des fonctionnalités proposées (et des problèmes connus).

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a [Pull Request](github.com/ZarTek-Creole/TCL-Clara-Service/pulls)

---
Les contributions sont ce qui fait de la communauté open source un endroit incroyable pour apprendre, inspirer et créer. Toute contribution que vous apportez est ** grandement appréciée **.
1. Forkez le projet
2. Créez votre branche de fonctionnalités (`git checkout -b feature/AmazingFeature`)
3. Validez vos modifications (`git commit -m 'Add some AmazingFeature'`)
4. Poussez vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une [Pull Request](github.com/ZarTek-Creole/TCL-Clara-Service/pulls)

<!-- LICENSE -->
## License

Distributed under the SoonDecision License. See `LICENSE` for more information.



<!-- CONTACT -->
## Contact

ZarTek - [@ZarTek](github.com/ZarTek-Creole) - ZarTek.Creole@GMail.com

Project Link: [github.com/ZarTek-Creole/TCL-Clara-Service](github.com/ZarTek-Creole/TCL-Clara-Service)

1. Tickets
Signalez tout bugs, toutes idées :
* [Creez un ticket]([#4-configuration-de-unrealircd](github.com/ZarTek-Creole/TCL-Clara-Service/issues))

2. IRC
Vous pouvez me contacter sur IRC :

   * [irc.epiknet.org 6667 #eggdrop](irc://irc.epiknet.org:6667/#eggdrop)
   * [irc.epiknet.org +6697 #eggdrop](irc://irc.epiknet.org:+6697/#eggdrop)

<!-- ACKNOWLEDGEMENTS -->
## Acknowledgements
* Amandine de eggdrop.Fr pour son aide/idées/testes/..
* MenzAgitat car dans mes developpements il y a toujours des astuces/maniere de faire fournis par MenzAgitat ou bout code de MenzAgitat




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
