<span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
[![CC BY 4.0][cc-by-shield]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg
# TCL-PKG-IRCServices
Package IRC Services

IRCServices creer une interface en TCL et la connexion d'un Service à un IRCD (comme anope).

# !!! VERSION ALPHA !!!
Developper et tester sur unrealircd v5+

Merci d'etre indulgent et repport bugs, idées, etc sur 
* [Creer un ticket](github.com/ZarTek-Creole/TCL-PKG-IRCServices/issues/new)
* [Site web: IRCServices](github.com/ZarTek-Creole/TCL-PKG-IRCServices)

# Pré requis
* tcllib (logger)

# Téléchargement
## Avec git (conseillé):

`git clone --recurse-submodules github.com/ZarTek-Creole/TCL-PKG-IRCServices.git /path/to/install`

## Avec wget :

```bash
wget github.com/ZarTek-Creole/TCL-PKG-IRCServices/archive/refs/heads/main.zip -O /path/to/install/TCL-PKG-IRCServices.zip
unzip -x TCL-PKG-IRCServices.zip
rm TCL-PKG-IRCServices.zip
```

# Installation
## avec setup.tcl (systeme) :

```bash
➜ cd /path/to/install
➜ sudo ./setup.tcl
tcltk/tcl8.6 /usr/lib/tcltk]
Installing /usr/lib/tcltk/IRCServices/pkgIndex.tcl
Installing /usr/lib/tcltk/IRCServices/ircservices.tcl
Done
➜  tclsh
% package require IRCServices
0.0.1
%
```

## avec auto_path (userdir):

Editez votre eggdrop.conf et ajouter avant vos source le repertoire contenant ircservices.tcl (/path/to/install)
```tcl
lappend auto_path /path/to/install
```
les commandes IRCServices seront disponible apres le chargement dans un tcl de celui-ci
```tcl
package require IRCServices
```

# Utilisation
```tcl
➜ tclsh
% package require IRCServices
0.0.1
% set CONNECT_ID [::IRCServices::connection]; # Creer une instance services
::IRCServices::IRCServices0::network
% $CONNECT_ID connect 
wrong # args: should be "::IRCServices::IRCServices0::cmd-connect hostname port password ?ts6? ?name? ?id?"
% $CONNECT_ID connect 127.0.0.0 +7500 passwordlink 1 eva.info 00C; # Creer une instance services
1
% set BOT_ID [$CONNECT_ID bot]; #Creer une instance bot dans linstance services
::IRCServices::IRCServices0::b0::bot
% $BOT_ID create
wrong # args: should be "::IRCServices::IRCServices0::b0::cmd-create botnick botident bothost ?botgecos? ?botmodes?"
% $BOT_ID create ClaraServ services ClaraServ.eggdrop.fr "Visit: https://git.io/JYY9b" +Soiq; # creer le botService et le connecte
1
% $BOT_ID join #Services; # le faire joindre le salon #Services
1
% $BOT_ID registerevent PRIVMSG {
                set cmd         [lindex [msg] 0]
                set data        [lrange [msg] 1 end]
                ##########################
                #--> Commandes Privés <--#
                ##########################
                # si [target] ne commence pas par # c'est un pseudo
                if { [string index [target] 0] != "#"} {
                        if { ${cmd} == "help"             }       { 
                                puts "PRIV: [who2] [target] ${cmd} ${data}"
                        }
                }
                ##########################
                #--> Commandes Salons <--#
                ##########################
                # si [target] commence par # c'est un salon
                if { [string index [target] 0] == "#"} {
                        if { ${cmd} == "!cmds"    }       { 
                                puts "PUB: [who] [target] ${cmd} ${data}"
                        }
                }
        }; # Creer un event sur PRIVMSG

}; # Creer un event sur PRIVMSG
1 
```