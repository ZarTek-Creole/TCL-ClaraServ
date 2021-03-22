#################################################################
##-->					TCL Clara Service					<--##
#---------------------------------------------------------------#
# Auteur Chris	: Support@Brothelnet.org
# Auteur yeh	: Clara@DreamTiZ.Fr
#---------------------------------------#
## Repris par MalaGaM
## Website	: https://github.com/MalaGaM/TCL-Clara-Service
## Support	: https://github.com/MalaGaM/TCL-Clara-Service/issues
## Greet	: 
##				-> Chris/Yeh pour versions antérieures
##				-> Amadine de www.eggdrop.fr
##################################################################
# Descriptif : 
#------------#
#
#	-> Animation de salon ( Chris - Yeh )
#	-> Aide de réseau ( Chris )
#	-> Profil d'utilisateur ( Yeh )
#	-> Plein d'autre chose seront mise plus tard.
#
##################################################################

set Clara(path) "[file dirname [info script]]/"
proc Clara:scriptdir {} {
	global Clara
	return $Clara(path)
}

################
# Clara Config #
################
proc Clara:config { } {
	global Clara
	set CONF_LIST	[list "ip" "info" "link" "port" "pass" "pseudo" "real" "ident" "host" "salon" "mode" "cmode" "console" "site" "version" "auteur" "equipe"]
			# ![info exists Admin(pseudo)]	[info exists Admin(password)]
	foreach CONF $CONF_LIST {
		if { ![info exists Clara($CONF)] } {
			putlog "\[ Erreur \] Configuration de Clara Service Incorrecte... '$CONF' Paramettre manquant"
			exit
		}
		if { $Clara($CONF) == "" } {
			putlog "\[ Erreur \] Configuration de Clara Service Incorrecte... '$CONF' Valeur vide"
			exit
		}
	}
}
################
# Clara Source #
################
if { [file exists [Clara:scriptdir]Clara.conf] } {
	source [Clara:scriptdir]Clara.conf
	Clara:config 
} else {
	if { [file exists [Clara:scriptdir]Clara.Example.conf] } {
		putlog "Editez, configurer et renomer 'Clara.Example.conf' en 'Clara.conf' dans '[Clara:scriptdir]'"
		exit
	} else {
		putlog "Fichier de configuration '[Clara:scriptdir]Clara.conf' manquant."
	}
}

if { ![file exists "[Clara:scriptdir]db/radios.db"] } {
	set c_radios	[open "[Clara:scriptdir]db/radios.db" a+];
	close $c_radios
}
if { ![file exists "[Clara:scriptdir]db/salon.db"] } {
	set c_salon	[open "[Clara:scriptdir]db/salon.db" a+];
	close $c_salon
}
####################
#--> Procedures <--#
####################
proc connexion {} {
	global Clara Admin botnick
	set eva(counter)		0
		if { ![catch "connect $Clara(ip) $Clara(port)" Clara(idx)] } {
			putlog "Successfully connected to uplink $Clara(ip) $Clara(port)"
			putdcc $Clara(idx) "PASS $Clara(pass)"
			putdcc $Clara(idx) "SERVER $Clara(link) 1 :$Clara(info)"
			putdcc $Clara(idx) ":$Clara(link) NICK $Clara(pseudo) 1 [unixtime] $Clara(ident) $Clara(host) $Clara(link) :$Clara(real)"
			putdcc $Clara(idx) ":$Clara(pseudo) MODE $Clara(pseudo) $Clara(mode)"
			putdcc $Clara(idx) ":$Clara(pseudo) JOIN $Clara(salon)"

			set fichier(salon) "[Clara:scriptdir]db/salon.db"
			set fp [open $fichier(salon) "r"]
			set fc -1
			while {![eof $fp]} {
				set data [gets $fp]
				incr fc
				if {$data !=""} {
					putdcc $Clara(idx) ":$Clara(pseudo) JOIN $data"
				}
				unset data
			}
			close $fp
			control $Clara(idx) event;
			utimer 30 verification
		} else {
			putlog "La connection échoué de Clara a $Clara(ip) $Clara(port)"
			exit
		}
}


######################
#--> Verification <--#
######################

if {![info exists Clara(idx)]} { connexion }
proc verification {} {
	global Clara Admin
	if {[valididx $Clara(idx)]} { utimer 30 verification } else { connexion }
}

proc event {idx arg} {
	global Clara Admin
	set chan	[join [lrange [split $arg] 0 0]]
	set arg		[split $arg]
	set arg2	[lindex $arg 1]
	set arg3	[lindex $arg 2]
	set arg4	[lindex $arg 3]
	set arg5	[lindex $arg 4]
	set arg6	[lindex $arg 5]
	set arg7	[lindex $arg 6]
	if { [lindex $arg 0] == "PING" } { 
		putdcc $Clara(idx) "PONG [lindex $arg 1]"; set Clara(counter) "0" 
	}
	if { [lindex $arg 0] == "NICK" } { 
		set nick	[string trim [lindex $arg 1] :]
		set ident	[string trim [lindex $arg 4] :]
		set host	[string trim [lindex $arg 5] :]
		set real	[string trim [lrange $arg 8 end] :]
		return 0
	}
	if { [lindex $arg 1] == "JOIN" } { 
		set nick	[string trim [lindex $arg 0] :]
		set chan	[string trim [lindex $arg 2] :]
		return 0
	}
	if { [lindex $arg 1]=="PART" } { 
		set nick [string trim [lindex $arg 0] :]
		set chan [string trim [lindex $arg 2] :]
		return 0
	}
	if { [lindex $arg 1]=="QUIT" } {
		set nick	[string trim [lindex $arg 0] :]
		set chan	[string trim [lrange $arg 2 end] :]
		set ident	[string trim [lindex $arg 4] :]
		set host	[string trim [lindex $arg 5] :]
		set real	[string trim [lrange $arg 8 end] :]
		return 0
	}
	switch -exact [lindex $arg 1] {
		"PRIVMSG" {
			set user	[string trim [lindex $arg 0] :]
			set vuser	[string tolower $user]
			set robot	[string tolower [lindex $arg 2]]
			set cmd		[string trim [stripcodes bcruag [string map {"\035" "" } [lindex $arg 3]]] :]
			set cmd2	[lindex $arg 4]
			set text	[lrange [split $arg] 5 end]
			set cmd3	[lindex $arg 5]

			##########################
			#--> Commandes Privés <--#
			##########################

			if { $cmd == "join" }	{ msg:join $cmd2 $user $cmd3 }
			if { $cmd == "part" }	{ msg:part $cmd2 $user $cmd3 }

			##########################
			#--> Commandes Salons <--#
			##########################

			if { $cmd == "!cmds" }			{ cmd $arg3 $user $cmd3 }
			if { $cmd == "!cmd" }			{ cmd $arg3 $user $cmd3 }
			if { $cmd == "!site" }			{ site $arg3 $user $cmd2 }
			if { $cmd == "!biere" }			{ biere $arg3 $user $cmd2 }
			if { $cmd == "!rateau" }		{ rateau $arg3 $user $cmd2 }
			if { $cmd == "!relou" }			{ relou $arg3 $user $cmd2 }
			if { $cmd == "!aime" }			{ aime $arg3 $user $cmd2 }
			if { $cmd == "!pelle" }			{ pelle $arg3 $user $cmd2 }
			if { $cmd == "!champagne" }		{ champagne $arg3 $user $cmd2 }
			if { $cmd == "!sexy" }			{ sexy $arg3 $user $cmd2 }
			if { $cmd == "!baffe" }			{ baffe $arg3 $user $cmd2 }
			if { $cmd == "!kiss" }			{ kiss $arg3 $user $cmd2 }
			if { $cmd == "!embrasse" }		{ embrasse $arg3 $user $cmd2 }
			if { $cmd == "!pv" }			{ kiss $arg3 $user $cmd2 }
			if { $cmd == "!whisky" }		{ whisky $arg3 $user $cmd2 }
			if { $cmd == "!rose" }			{ rose $arg3 $user $cmd2 }
			if { $cmd == "!coca" }			{ coca $arg3 $user $cmd2 }
			if { $cmd == "!calin" }			{ calin $arg3 $user $cmd2 }
			if { $cmd == "!love" }			{ love $arg3 $user $cmd2 }
			if { $cmd == "!radio" }			{ radio $arg3 $user $cmd2 }

			if { $cmd == "!clope" }			{ clope $arg3 $user $cmd2 }
			if { $cmd == "!cafe" }			{ cafe $arg3 $user $cmd2 }

			if { $cmd == "!café" }			{ cafe $arg3 $user $cmd2 }
			if { $cmd == "!thé"}			{ the $arg3 $user $cmd2 }
			if { $cmd == "!fessée" }		{ fessee $arg3 $user $cmd2 }
			if { $cmd == "!mord" }			{ mord $arg3 $user $cmd2 }

			if { $cmd == "!fesses" }		{ fesses $arg3 $user $cmd2 }
			if { $cmd == "!tendresse" }		{ tendresse $arg3 $user $cmd2 }
			if { $cmd == "!danse" }			{ danse $arg3 $user $cmd2 }
			if { $cmd == "!noir" }			{ noir $arg3 $user $cmd2 }
			if { $cmd == "!fouet" }			{ fouet $arg3 $user $cmd2 }
			if { $cmd == "!chocolat" }		{ chocolat $arg3 $user $cmd2 }
			if { $cmd == "!fleur" }			{ fleur $arg3 $user $cmd2 }
			if { $cmd == "!coeur" }			{ coeur $arg3 $user $cmd2 }
			if { $cmd == "!mouton" }		{ mouton $arg3 $user $cmd2 }
			if { $cmd == "!video" }			{ video $arg3 $user $cmd2 }
			if { $cmd == "!chante" }		{ chante $arg3 $user $cmd2 }
			if { $cmd == "!cochon" }		{ cochon $arg3 $user $cmd2 }
			if { $cmd == "!seau" }			{ seau $arg3 $user $cmd2 }
			if { $cmd == "!waff" }			{ waff $arg3 $user $cmd2 }
			if { $cmd == "!eau" }			{ eau $arg3 $user $cmd2 }
			if { $cmd == "!truite" }		{ truite $arg3 $user $cmd2 }
			if { $cmd == "!jump" }			{ jump $arg3 $user $cmd2 }
			if { $cmd == "!dzoss" }			{ dzoss $arg3 $user $cmd2 }
			if { $cmd == "!apero" }			{ apero $arg3 $user $cmd2 }
			if { $cmd == "!dodo" }			{ dodo $arg3 $user $cmd2 }
			if { $cmd == "!piscine" }		{ piscine $arg3 $user $cmd2 }
			if { $cmd == "!saute" }			{ saute $arg3 $user $cmd2 }
			if { $cmd == "!bouge" }			{ bouge $arg3 $user $cmd2 }
			if { $cmd == "!mojito" }		{ mojito $arg3 $user $cmd2 }
			if { $cmd == "!glace" }			{ glace $arg3 $user $cmd2 }
			if { $cmd == "!ruisseau" }		{ ruisseau $arg3 $user $cmd2 }
			if { $cmd == "!lune" }			{ lune $arg3 $user $cmd2 }
			if { $cmd == "!zen" }			{ zen $arg3 $user $cmd2 }
			if { $cmd == "!rhum" }			{ rhum $arg3 $user $cmd2 }
			if { $cmd == "!clé" }			{ cle $arg3 $user $cmd2 }
			if { $cmd == "!string" }		{ stringcmds $arg3 $user $cmd2 }
			if { $cmd == "!bjr" }			{ bjr $arg3 $user $cmd2 }
			if { $cmd == "!bye" }			{ bye $arg3 $user $cmd2 }
			if { $cmd == "!ange" }			{ ange $arg3 $user $cmd2 }
			if { $cmd == "!étoile" }		{ etoile $arg3 $user $cmd2 }
			if { $cmd == "!orangina" }		{ orangina $arg3 $user $cmd2 }
			if { $cmd == "!milkshake" }		{ milkshake $arg3 $user $cmd2 }
			if { $cmd == "!massage" }		{ massage $arg3 $user $cmd2 }
			if { $cmd == "!7up" }			{ 7up $arg3 $user $cmd2 }
			if { $cmd == "!tropicana" }		{ tropicana $arg3 $user $cmd2 }
			if { $cmd == "!macdo" }			{ macdo $arg3 $user $cmd2 }
			if { $cmd == "!perf" }			{ perf $arg3 $user $cmd2 }
			if { $cmd == "!redbull" }		{ redbull $arg3 $user $cmd2 }
			if { $cmd == "!curly" }			{ curly $arg3 $user $cmd2 }
			if { $cmd == "!vittel" }		{ vittel $arg3 $user $cmd2 }
			if { $cmd == "!carambar" }		{ carambar $arg3 $user $cmd2 }
			if { $cmd == "!anni" }			{ anni $arg3 $user $cmd2 }
			if { $cmd == "!pizza" }			{ pizza $arg3 $user $cmd2 }
			if { $cmd == "!mms" }			{ mms $arg3 $user $cmd2 }
			if { $cmd == "!mars" }			{ mars $arg3 $user $cmd2 }
			if { $cmd == "!plouf" }			{ plouf $arg3 $user $cmd2 }
			if { $cmd == "!croissant" }		{ croissant $arg3 $user $cmd2 }
			if { $cmd == "!chocolatine" }	{ chocolatine $arg3 $user $cmd2 }
			if { $cmd == "!patate" }		{ patate $arg3 $user $cmd2 }
			if { $cmd == "!pouet" }			{ pouet $arg3 $user $cmd2 }
			if { $cmd == "!oignon" }		{ oignon $arg3 $user $cmd2 }
			if { $cmd == "!vent" }			{ vent $arg3 $user $cmd2 }
			if { $cmd == "!écran" }			{ ecran $arg3 $user $cmd2 }

			if { $cmd == "!boude" }			{ boude $arg3 $user $cmd2 }
			if { $cmd == "!gratte" }		{ gratte $arg3 $user $cmd2 }
			if { $cmd == "!popcorn" }		{ popcorn $arg3 $user $cmd2 }
			if { $cmd == "!shocked" }		{ shocked $arg3 $user $cmd2 }
			if { $cmd == "!mariage" }		{ mariage $arg3 $user $cmd2 }
			if { $cmd == "!bus" }			{ bus $arg3 $user $cmd2 }
			if { $cmd == "!kebab" }			{ kebab $arg3 $user $cmd2 }
			if { $cmd == "!triste" }		{ triste $arg3 $user $cmd2 }
			if { $cmd == "!vnr" }			{ vnr $arg3 $user $cmd2 }
			if { $cmd == "!gateau" }		{ gateau $arg3 $user $cmd2 }
			if { $cmd == "!gaufre" }		{ gaufre $arg3 $user $cmd2 }
		}
	}
}

#######################
#  --> Commandes <--  #
#######################

##########################################
# --> Procedures des Commandes Salons <--#
##########################################
proc cmd { chan nick pseudo } {
	global Clara Admin
	set vuser	[string tolower $nick]
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034.: \00312Liste des commandes d'animation \0034:."
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!site \0031- \00312!tendresse \0031- \0034!mord \0031- \00312!danse \0031- \0034!fouet \0031- \00312!bjr \0031- \0034!bye \0031- \00312!étoile \0031- \0034!orangina \0031- \00312!milkshake \0031- \0034!redbull"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!café \0031- \00312!champagne \0031- \0034!biere \0031- \00312!kiss \0031- \0034!chocolat \0031- \00312!rose \0031- \0034!pelle \0031- \00312!calin \0031- \0034!fleur \0031- \00312!massage \0031- \0034!curly"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!embrasse \0031- \00312!coca \0031- \0034!baffe \0031- \00312!relou \0031- \0034!aime \0031- \00312!sexy \0031- \0034!love \0031- \00312!coeur \0031- \0034!clope \0031- \00312!fesses \0031- \0034!vittel"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!mouton \0031- \00312!chante \0031- \0034!cochon \0031- \00312!thé \0031- \0034!whisky \0031- \00312!seau \0031- \0034!waff \0031- \00312!eau \0031- \0034!truite \0031- \00312!dzoss \0031- \0034!carambar"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!apero \0031- \00312!dodo \0031- \0034!piscine \0031- \00312!rhum \0031- \0034!saute \0031- \00312!bouge \0031- \0034!clé \0031- \00312!fessée \0031- \0034!string \0031 - \00312!7up \0031- \0034!anni"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!mojito \0031- \00312!glace \0031- \0034!ruisseau \0031- \00312!video \0031- \00312!lune \0031- \0034!zen \0031- \00312!jump \0031- \0034!noir \0031- \00312!ange \0031- \0034!macdo \0031- \00312!perf \0031- \0034!pizza"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!mms \0031- \00312!mars \0031- \0034!plouf \0031- \00312!croissant \0031- \0034!chocolatine \0031- \00312!patate \0031- \0034!pouet \0031- \00312!oignon \0031- \0034!vent \0031- \00312!écran"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034!boude \0031- \00312!gratte \0031- \0034!popcorn \0031- \00312!shocked \0031- \0034!mariage \0031- \00312!bus \0031- \0034!kebab \0031- \00312!triste \0031- \0034!vnr \0031- \00312!gateau \0031- \0034!gaufre"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0037!horo \0031- \0036!tapavu \0031- \0037!vdm \0031- \0036!chuck \0031- \0037!jcvd \0031- \0036!oracle *"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034"
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\0034 * \002Note:\002 Il y a certaine commandes qui ne sont pas activées sur tous les salons."
	if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Commandes : \0034$nick" }
}

proc radio { chan nick pseudo } {
	global Clara Admin
	set vuser			[string tolower $nick]
	set fichier(radios)	"[Clara:scriptdir]db/radios.db"
	set fp [open $fichier(radios) "r"]
	set fc -1
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\002\0031 *** \0033♫♫\0031 Liste des radios sur Ch\00312a\00313a\0031t.fr \0033♫♫ \0031*** "
	while {![eof $fp]} {
		set data [gets $fp]
		incr fc
		if {$data !=""} {
			putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\002\00314 [lindex $data 0]\0031 ⏩\0037 [lindex $data 1] \0031 ⏩\0036 [lindex $data 2] \0034 ♪♫"
		}
		unset data
	}
	close $fp
	putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $nick :\002\0031 Bonne écoute et bon TChat \0033♫♫\0031 ❗ "
	if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Radio : \0034$nick" }
}

proc site { chan user pseudo } {
	global Clara Admin
	putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0034Site officiel de \0031Ch\00312a\00313a\0031t.fr : \00312$Clara(site)"
	if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Site : \0034$user"}
}

proc rhum { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il fait chauuuuuuuud, \0037$user \00312se sert un p'tit verre de rhum \0034ah ah ah ah... du rhum des femmes et du son nom de dieu !!! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312paye un verre de rhum à \0034$pseudo \00312, à la tienne biloute :p ça pique hein ^^ "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (rhum)"}
	}
}

proc chocolat { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Que de gourmandise,\0037$user \00312s'autorise 1 carré de chocolat ... puis 2 ... puis 3 ... A cette allure, d'ici\0034 10 minutes \00312tout le paquet va y passer !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312C'est pour toi ! Oui oui,\0037$user \00312souhaite te faire plaisir et t'offre ces quelques carrés de chocolat. Offerts de bon coeur pour\0034 $pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (chocolat)"}
	}
}

proc danse { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312On dirait que\0037$user\00312 a une envie folle de danser !! \002\0034ƪ(˘⌣˘)┐ ƪ(˘⌣˘)ʃ ┌(˘⌣˘)ʃ"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312a le corps qui bouge et aimerait inviter \0034$pseudo \00312à danser, serrés l'un contre l'autre\002\0034 ヘ( ^o^)ノ＼(^_^ )"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (danse)"}
	}
}

proc fleur { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre des fleurs \0034(elle-lui)-même!\0034✿\0033❀\0037❁"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre de belles \0034@\0033-,\0033-'\0033--,\0033- \0037@\003\0033-,-'--- \0036@\0033-,-'--,--\00312 à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (fleur)"}
	}
}

proc coeur { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312aime \0034les coeurs  \0036\♥\00313\(\¯\`\♥\´\¯\)\0036\♥"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00313❤\0036❤\0037❤\0032❤\0034\002 $pseudo \002\0032❤\0037❤\0036❤\00313❤ "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (coeur)"}
	}
}

proc mouton { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312soit un mouton ^^ \0034béééééééééééééééééééééé "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312a une soudaine envie de faire le mouton pour \0034$pseudo\00312. bééééééééééééééééééééééé "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (mouton)"}
	}
}

proc rateau { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se soit pris le rateau de l'année ! \002\0034 (✖╭╮✖)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312 dit: Quand tu te prends un râteau dans les dents, c'est avec la pelle que l'on te ramasse \0034$pseudo \002\0034(Q'-')=O (✖╭╮✖)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (rateau)"}
	}
}

proc chante { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312chante à tue-tête \0034lalalalalalalala.\00312 L'année prochaine c'est inscription à The Voice DIRECT ! 🎵 🎶"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312prend le micro et monte sur son bureau pour chanter avec \0034 $pseudo. \00312On va faire péter les baffles yéééééééé \0034♫♪.ılılıll|̲̅̅●̲̅̅|̲̅̅=̲̅̅|̲̅̅●̲̅̅|llılılı.♫♪"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (chante)"}
	}
}

proc cochon { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312 spider cochon, spider cochon, il peut marcher au plafond, est-ce qu'il peeeut faire la toile, bien sûr que non, c'est un cochon. Prends garde !! spider cochon \00313^(°@°)^ \00312est là !!!!!!! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit que\0034 $pseudo \00312 est un(e) cochon(ne)\00313^(°@°)^ \00312. Vas-y roule-toi dans la boue et va manger des glands :x "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (cochon)"}
	}
}

proc the { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Coooooool ! \0037$user \00312part en cuisine pour préparer \0034du thé \002\0035\[\_\_\]\D\ "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan : \0037$user \00312offre une bonne tasse de Thé toute chaude à \0034$pseudo \00312 >> Une rondelle de citron, du lait, du sucre ? \002\0035\[\_\_\]\D\ "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (the)"}
	}
}

proc seau { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \0034se vide un seau d'eau froide sur la tête.\00312 Tu as trop chaud \0037$user \00312? "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312balance un seau d'eau froide sur\0034 $pseudo. \00312Ca va te calmer je pense ;) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (seau)"}
	}
}

proc waff { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est un(e) petit(e) caniche, peluche pour vieux :D "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037Waff \00312est mort de rire en imaginant \0034$pseudo \00312s'acharner contre un meuble comme un caniche en manque xD l'image est moche mais rigolote :D "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (waff)"}
	}
}

proc eau { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \0034se vide un seau d'eau froide sur la tête.\00312 Tu as trop chaud \0037$user \00312? "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312balance un seau d'eau froide sur\0034 $pseudo. \00312Ca va te calmer je pense ;) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user eau)"}
	}
}

proc jump { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\002\0032,0<\00307,00o\00303,00/ \00304,0Jump \0031o \00306,0Jump \0031o \00310,0Jump \0031o \00303,0Jump \0031o \00314,0Jump \0031o \0037,0Jump \0031o \00305,00\00310,00o\00304,00> "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\002\0032,0<\00307,00o\00303,00/ \00304,0Jump \0031o \00306,0Jump \0031o \00310,0Jump\0031 $pseudo \00303,0Jump \0031o \00314,0Jump \0031o \0037,0Jump \0031o \00305,00\00310,00o\00304,00> "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (jump)"}
	}
}

proc truite { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \0034se flagelle la tronche à coup de truite \00312>(////°> "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312met de gros coups de \0031>(////°> \00312 à \0034$pseudo "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (truite)"}
	}
}

proc dzoss { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se D-Zoss \0034(elle-lui)-même ! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312 se jette violement sur \0034$pseudo \00312pour le-la D-Zosser. "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user dzoss)"}
	}
}

proc apero { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \0034déclare qu'il est l'heure de sortir les bouteilles du bar pour l'apéro ! Qui s'occupe des cacahuètes et des chips ? :p  "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312demande à\0034 $pseudo \00312ce qu'(il-elle) veut boire car c'est l'heure de l'apéro la ! C'est parti pour un petit pastis, Sky cola ou un jus de fruit ! \0037\(* ˘⌣˘)◞\0031d\[\_\]\ \00312Tchin !\0031 \[\_\]b\0034\ヽ(•‿• ) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (apero)"}
	}
}

proc dodo { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312va aller faire un bon gros dodo \0034(-.-)Zzz...\00312 et souhaite une bonne nuit à tout le monde. Faites de doux rêves les ami(e)s\0034\002 ヽ(´ー`)人(´∇｀)人(`Д´)ノ "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312aimerait bien se faire border par\0034 $pseudo \00312car c'est l'heure d'aller au dodo ^^ ! Bonne nuit <3 "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (dodo)"}
	}
}

proc piscine { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \0034n'a pas l'air d'être dispo... \00312J'peux pas j'ai pisciiiiiine cine cine cine j'peux pas j'ai pisciiiiiiiiineuh "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312rappel à\0034 $pseudo \00312qu'(il-elle) n'est pas dispo, (il-elle) a pisciiiiiiiiiine !!! "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (piscine)"}
	}
}

proc saute { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0033O\0034\002n \0036S\0035\002a\00313u\0037\002\002T\00310\002e\00314, \0031\002S\0034\002a\0032\002U\00313t\00314\002E\0035, \0036\002s\0037A\0033\002u\00310T\00313\002e\0031... h\002O\002p h\002O\002p h\002O\002p \00312on met le feu sur\002\0034 $chan \002\0031ou quoi ? "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037\002$user \0036S\0035\002a\00313u\0037\002\002T\00310\002e\00314, \0031\002S\0034\002a\0032\002U\00313t\00314\002E\0035, \0036\002s\0037A\0033\002u\00310T\00313\002e\0034\002$pseudo "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (saute)"}
	}
}

proc bouge { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0031Sur les C\002h\002\00312a\002\00313a\002\0031t \002R\002a\002d\002i\002O\002o \0031on a La maladie du \002\0034B\002\0031ouger \0034\002B\0031\002ouger, on s'assoit pas ! \0036\002J\0037u\00313m\0033P \0034J\00312u\00310m\00314P \0036J\0037u\00313m\0033P \0034J\00312u\00310m\00314P "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0036\002J\0037u\00313m\0033P \0034J\00312u\00310m\00314P \0036J\0037u\00313m\0033P \0034J\00312u\00310m\00314P \0031Lève-toi et danse\0034 $pseudo\0031, c'est\0034 $user \0031qui te le demande \0036J\0037u\00313m\0033P \0034J\00312u\00310m\00314P \0036J\0037u\00313m\0033P \0034J\00312u\00310m\00314P "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (bouge)"}
	}
}

proc mojito { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312paye sa tournée de \0033Mojito ! \00312ohhhhhhh ouiiiiiiii c'est parti hi hi hi ! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est de bonne humeur et offre à\0034 $pseudo \00312un \0033Mojito \00312de la mort qui tue \0031☠\00312 ! C'est parti pour faire la fête :D "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (mojito)"}
	}
}

proc glace { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Quelle chaleur ... \0037$user \00312 a une de ces envies de sucer ... une glace ^^ "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312fonce au congel et annonce les parfums à\0034 $pseudo \00312: vanille, chocolat, fraise, rhum raisin, banane laurier, steak frite ☚ (<‿<)☚ ... tu veux quoiiiii comme glace ? "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (glace)"}
	}
}

proc ruisseau { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Tu es assis près d'un ruisseau et tu as soif, même si tu es idiot(e), tu sais que l'eau va te désaltérer. \0034C'est ça comprendre... "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312aimerait bien faire comprendre à\0034 $pseudo \00312que si tu es assis(e) près d'un ruisseau et que tu as soif, même si tu es idiot(e), tu sais que l'eau va te désaltérer.\0034 C'est ça comprendre... "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (ruisseau)"}
	}
}

proc lune { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312 Quand le sage désigne la lune, l'idiot regarde le doigt... regarde la lune ☽ s'il te plait ! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312a beaucoup de sagesse... Quand le sage désigne la lune ☽, l'idiot regarde le doigt... \0034$pseudo \00312regarde la lune s'il te plait ! "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (lune)"}
	}
}

proc zen { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312 Chaque fois qu'une personne sourit, elle ajoute quelque chose à la durée de sa vie, restes ZeN ☯ et tu vivras longtemps. "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312 Chaque fois qu'une personne sourit, elle ajoute quelque chose à la durée de sa vie, restes ZeN ☯\0034 $pseudo \00312 et tu vivras longtemps. "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (zen)"}
	}
}

proc noir { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312il va faire \0031noiiiiiiiiiir\00312 ...! \0037$user \00312va fermer sa yeule ! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312il va faire \0031noiiiiiiiiiir !!! \0037$user \00312demande à\0034 $pseudo \00312de fermer sa yeule !"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (noir)"}
	}
}


proc video { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312va aller se matter une bonne vidéoooooooooooooooooooo\0034\002 \[\●▪▪●\]\ "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312chuchote à l'oreille de \0034$pseudo \00312qu'(il-elle) ferait mieux d'aller se matter une vidéo\0034 \[\●▪▪●\]\ \00312... ça détend ^^ tu seras moins stressé(e) et plus détendu(e) :) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (video)"}
	}
}

proc clope { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre une bonne pause clope bien meritée (c'est pas bien de fumer)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une cigarette (\037\0031,7)¯¯¯¯\003)\0031¯\00312)\0031,0¯¯¯¯¯¯¯\037\002))\003\0034,0)\00315~~\017 \00312 à \0034$pseudo \00312(c'est pas bien de fumer)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (clope)"}
	}
}

proc mord { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se mord (elle-lui)-même, sado maso ?"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312choppe \0034$pseudo \00312et lui mord ses fesses humm ce gout de \00313\002<3 <3 <3"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (mord)"}
	}
}

proc tendresse { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312se donne un peu de tendresse à (elle-lui)-même, puisque personne ne lui en donne \00313(♥‿♥)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312prend \0034$pseudo\00312 dans ses bras, et lui fait un super calin <3 C'est ça l'amour \00313♥(Ɔ ˘⌣˘)˘⌣˘ C)♥"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (tendresse)"}
	}
}

proc cafe { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Génial ! \0037$user \00312part en cuisine pour préparer du \0031,1_\0030C\0031_\002\0031,0]\002 \0034,4_\0030a\0034_\002\0034,0]\002 \0032,2_\0030f\0032_\002\0032,0]\002 \0033,3_\0030é_\002\0033,0]"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une bonne tasse de \0031,1_\0030C\0031_\002\0031,0]\002 \0034,4_\0030a\0034_\002\0034,0]\002 \0032,2_\0030f\0032_\002\0032,0]\002 \0033,3_\0030é\0033_\002\0033,0]\002\003\00312 toute chaude à \0034$pseudo \00312>> Un peu de lait, du sucre ? "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (cafe)"}

	}
}

proc fesses { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312bouge son p'tit cul sur la piste \0034(_\\_) (_|_) (_/_) (_|_) (_\\_) !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan : \0037$user \00312monte sur la piste de danse et remue son p'tit cul\0034 (_\\_) (_|_) (_/_) (_|_) (_\\_)\00312 avec \0034$pseudo !"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (fesses)"}

	}
}

proc fessee { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user\00312 va donner une bonne fessée à ceux/celles qui le méritent ! Attention !!\0034 :PPP"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312met une grosse fessée qui CLAQUEeeeee sur les fesses rebondies de \0034$pseudo \00312il/elle doit surement aimer ca pour en redemander, sado maso??\0034 :PPP"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (fessee)"}

	}
}

proc biere { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre une bonne biere fraiche à \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une bonne biere fraiche à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (biere)"}
	}
}

proc pelle { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se roule une pelle à \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312roule une bonne pelle à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (pelle)"}
	}
}

proc kiss { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se fasse un énorme \0034K\0037iii\0036ii\0032sss \00312à \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312fait un énorme \0034K\0037iii\0036ii\0032sss à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (kiss)"}
	}
}

proc champagne { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre une coupe de champagne à \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une bonne coupe de champagne à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (champagne)"}
	}
}

proc sexy { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se trouve \0034(elle-lui)-même ! \00312très sexy. \0034٩(- ̮̮̃-̃)۶\00312( Les chevilles gonflent :o) )"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312te trouve vraiment \0034três \00313très \0037SEXY!!! \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (sexy)"}
	}
}

proc aime { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'aime \0034(elle-lui)-même ! \00313 ♥‿♥"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312déclare devant toute la salle qu'il aime \0034$pseudo !!\00313 (ღ˘⌣˘)♥♥♥♥♥ "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (aime)"}
	}
}

proc relou { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se trouve relou \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312trouve vraiment que \0034$pseudo \00312est très relou."
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (relou)"}
	}
}

proc baffe { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312se met une baffe \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312met une groOsse baffe à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (baffe)"}
	}
}

proc embrasse { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'embrasse \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312embrasse tendrement \0034$pseudo \00312jusqu'à ne plus avoir de bouche.\00313(Ɔ ˘⌣˘)♥(˘⌣˘ C)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (embrasse)"}
	}
}

proc whisky { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre un bon whisky \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre un bon verre de whisky à \0034$pseudo \00312Hmmm :D"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (whisky)"}
	}
}

proc coca { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre un \0034CoCa®\0031-\0032Cola \0034(elle-lui)-même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une cannette de \0034CoCa\0031-\0032Cola®\00312 à \0034$pseudo \00312Hmmm :D"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (coca)"}
	}
}

proc rose { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre une rose \0034(elle-lui)-même !\0033--------\{---\0034(@"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une belle rose \0033---<--´,--<\{-\0034@ \00312à \0034$pseudo"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (rose)"}

	}
}

proc calin { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0033$user \00312s'enlace \0037(elle-lui)-même ! \00313❤❤❤"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0034 $user \00312prend \0034$pseudo \00312dans ses bras et lui fait un énorme calin \00313❤❤❤"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (calin)"}

	}
}

proc love { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'aime de tout son coeur \0034 ( ˘ ³˘)\00313❤ ᶫᵒᵛᵉᵧₒᵤ !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312t'aime de tout son coeur \0034$pseudo ! \00312DéClaration devant vous sur \00313$chan ! \0034(Ɔ ˘⌣˘)♥(˘⌣˘ C)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (love)"}
	}
}

proc fouet { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0034$pseudo \00312aime se mettre des coups de fouet \002\0031===\0035~~~~~~"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312fouette vigoureusement \0034$pseudo\00312. T'aime ça coquin(e) hein \002\0031===\0035~~~~~~"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (fouet)"}
	}
}

proc cle { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312Prend la clé\0034 ╥―O ⚿ \00312des champs car (il-elle) aurait du la fermer !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Tiens voilà la clé\0034 ╥―O ⚿ \00312pour fermer ta bouche \0034$pseudo\00312, ça nous fera des vacances !"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (cle)"}
	}
}

proc stringcmds { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit le string est le premier instrument à cordes, quand on pète ça fait une mélodie\0034 PweT ! ♪ ♫ ♩"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312 il ne faut pas trop tirer sur la ficelle de son string \0034$pseudo \00312sinon... tu l'as dans le Q !!! "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (string)"}
	}
}

proc bjr { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit un grand Bonjour ou Bonsoir à\0034 tout le monde !\002 ヽ(•‿•)ノ"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit un grand Bonjour ou Bonsoir à \0034$pseudo !\002 ヽ(•‿•)ノ"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (bjr)"}
	}
}

proc bye { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312souhaite une bonne nuit ☾ à\0034 tout le monde ! \002(*・‿・)ノ*`*`*\002\00312 A demain les Ami(e)s !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312souhaite une bonne nuit ☾ à \0034$pseudo\0034\002 ! (*・‿・)ノ*`*`*\002\00312 Bye Bye !"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (bye)"}
	}
}


proc etoile { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312se lance de la poussière d'étoile \0037';`*^',*;~`;.,*`.`*~;*~`;,.'*`.;*``;.^.*`~..;`*.^;.,*`;~..*;`~*.,:*`** \00312car (il-elle) se trouve vraiment \002\0034SPÉCIAL ! "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312lance de la poussière d'étoile tout autour de \0034$pseudo \0037';`*^',*;~`;.,*`.`*~;*~`;,.'*`.;*``;.^.*`~..;`*.^;.,*`;~..*;`~*.,:*`** \00312parce-que TU es vraiment \002\0034SPÉCIAL ! "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (etoile)"}
	}
}

proc ange { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user\00312 soit un ange ! \00313~Å~ \0032~Å~ \00312~Å~	"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312t'envoie de petits anges gardiens pour te surveiller \0034$pseudo \00313~Å~ \0032~Å~ \00312~Å~ \0034$pseudo \0033~Å~ \00310~Å~ \00313~Å~ \0034$pseudo \00311~Å~ \0036~Å~ \00314~Å~ \0034$pseudo \00315~Å~ \00313~Å~ \00314~Å~"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (ange)"}
	}
}


proc orangina { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Il semblerait que \0037$user \00312s'offre un \002\0038,12~ORANGINA®~ \002\00312,0à (elle-lui)-même ! hmmm :D"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une cannette d'\002\0038,12~ORANGINA®~ \002\00312,0 à \0034,0$pseudo \00312Il faut bien le secouer ! Hmmm :D"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (orangina)"}
	}
}

proc milkshake { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0034$pseudo \00312nargue tout le monde avec son \002\0033Mi\0036L\002kS\00313h\002Ak \002\0034 凸( ^o^)ノ\0031└┘\00312 !!!"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312C'est l'heure duuuuuuuuuuu \0033\002Mi\0036L\002kS\00313h\002Ak\0037E \002S\002\00310hak\002\0032e S\0034h\002a\0031ki B\002\0033oO\002m\0032\002 \0034$user \00312paie sa tournée à \0034$pseudo ! \002\0034 ( ^o^)ノ\0031└┘└┘\0034＼(^_^ ) \002\00312 Wèèèè !"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (milkshake)"}
	}
}


proc massage { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312demande s'il y aurait quelqu'un pour lui faire un \0030M\0032M\0033M\0034a\0035a\0036a\0037\0039S\00310S\00311a\00312a\00313a\0032G\0034G\0035G\0036e\0037e\0038e\00312 ???\0034 J'en rêve !\002\0034 (ô‿ô)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312avec de l'huile \0033❝Revitalise❞ \00312se lance dans un \0030M\0032M\0033M\0034a\0035a\0036a\0037\0039S\00310S\00311a\00312a\00313a\0032G\0034G\0035G\0036e\0037e\0038e\00312 sur \0034$pseudo \00312pour favoriser la détente et le bien-être ! ça fait du BiiiiiieN !\002\0034 (Ö‿Ö)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (massage)"}
	}
}

proc 7up { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Que ça fait du bien, un bon \0030,3\0027\0034•\0030,3Up®\002\0032,0\003\00312 bien frais, n'est-ce pas ? \0037$user \00312en prend un pour la peine !\0034 HAaAaAaA !!!"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0030,3\0027\0034•\0030,3Up®\002\0032,0\003\00312 est une boisson gazeuse à la saveur de citron-lime créée au début des années 1920 par Charles Leiper Grigg ... Blablabla xD t'en veux \0034$pseudo \00312?"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (7up)"}
	}
}


proc tropicana { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Quelles sont belles ces \0037Oranges\002 ◯◯◯ \002\00312!!! \0037$user \00312va s'en faire un bon jus version \002\0033,7Tropícana®"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Besoin de vitamines \0034$pseudo \00312? Pas de soucis, \0037$user\00312 va te presser quelques Oranges \002\0037◯◯◯\002\00312 en mode \002\0033,7Tropícana®"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (tropicana)"}
	}
}


proc macdo { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Ouuuuuèèèèè ! \0037$user \00312va se faire péter le Bide avec un hamburger \0038,4\002Big /¥\\ac®\0036,0\0034 ヽ(^。^)ノ\00312MiaM !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312donne un hamburger \0038,4\002Big /¥\\ac®\0036,0\002 à\0037\002\0034 $pseudo ! ヽ(^。^)ノ"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (macdo)"}
	}
}


proc perf { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312O\0033u\0034l\0035a\0036l\0037a\00313l\00314a\00312 ! \0037$user \002\0034ε(๏̯͡๏)з\002\00312 a du mal à se Reveiller ! Une bonne Perfusion de café ☕ pour ne plus avoir la tête dans le \002\0034(_|_)\00312 \002 !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312O\0033u\0034l\0035a\0036l\0037a\00313l\00314a\00312 ! \0037$user \00312propose une bonne Perfusion de café ☕ à \0034$pseudo \002\0034ε(๏̯͡๏)з\002\00312 qui a la tête dans le \002\0034(_|_)\00312 \002 !"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (perf)"}
	}
}

proc redbull { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312La boisson énergétique \002\0034,2Red\0034,15Bull®\002\00312,0 ne donne pas d'ailes mais \0037$user \00312s'en fiche, il-elle s'en boit une canette quand même !"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312En cas de coup de mou\002\00314(•̪●)\002\00312, \0037$user\00312 conseil à \0034$pseudo\00312 de prendre une canette de \0032 \002\0034,2Red\0034,15Bull®\002\00312,0 il parait que ça donne des ailes \002\0034Ƹ(̾●̮̮̃̾•̃̾)Ʒ "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (redbull)"}
	}
}


proc curly { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312n'a pas d'amis\002\0034 (✖╭╮✖)\002\00312 ...... qui lui offre des \002\0038,4 Curly®\002 \0032,0 ?"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit Si t'as pas d'amis ! Prends un\0038,4\002 Curly®\002\0031,0 \0034$pseudo ! \002( ˘⌣˘)/(⌣́_⌣̀)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (curly)"}
	}
}


proc vittel { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312T'es malade ou quoi \0034$user \002\0034(☉_☉)\00312 ?\002\00312 tu te mets à boire de la \0031\[ \00312■\002\0034Vittel® \0031\002\]\00312,0 ... ou alors c'est peu être pour noyer le \002\0030,2\[Ricard®\0038,2☀\0030,2\] "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Elle est si bonne ma \0031\[ \00312■\002\0034Vittel® \0031\002\]\00312,0 que j'en fais profiter les amis ;) Un petit verre \0034$pseudo \00312? C'est \0037$user \00312qui paie sa tournée ...	Mais t'inquiète, on oublie pas le \002\0030,2\[Ricard®\0038,2☀\0030,2\]\002\00312,0 qui va avec !\002\0034 ( -‿•)◞└┘└┘ヽ(˘‿˘ ) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (vittel)"}
	}
}

proc carambar { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312S'offre un \0030,6 \0030,0 \0035,8 \002CaRaMbAR® \0030,6\002\0030,0 \0030,6 \00312,0 pour sortir une bonne Blagounette !\0034\002 ƪ(ړײ)‎ƪ​​"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312Se demande si la blague de \0034$pseudo \00312ne vient pas de la série \0033 ❝ Blagues Loupées ❞\00312 de chez \0030,6	\0030,0 \0035,8	\002CaRaMbAR® \0030,6\002\0030,0 \0030,6 \00312,0 \0034\002 (•̪(•̪●)̪●)​​ \002\00312<( \037Mince le Bide .....)\037"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (carambar)"}
	}
}


proc anni { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\037\0034Anniversaire\037\00312: Evènement qui se répète avec une régularité et une précision \0033inéluctables\00312 ! ⌛. C’est ainsi qu'aujourdhui, à la date prévue initialement \0037$user \00312vous dit : c'est \002\0037★ *˛ ˚\0034❤* \0033✰。˚ \00312MoN\ Anniversaire !!! \0033˚✰  。\0034❤˚* ˚\0037 ★"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312demande à \0034$pseudo \00312si le poids des bougies dépasse celui du gâteau ! Car aujourdhui c'est \002\0037★ *˛ ˚\0034❤* \0033✰。˚ \00312SoN  Anniversaire !!! \0033˚✰	。\0034❤˚* ˚\0037 ★\00312 \002 bon Anni \0034$pseudo\00312 ! \002\00313(っ˘з(˘⌣˘ )"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (anni)"}
	}
}

proc pizza { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312s'offre une PizZa juste sortie du four \0034♨\00312 de \0033,3\[ \]\0030,0\[ \]\0030,4 Pizza Hut® \0030,0\[ \]\0033,3\[ \]\003\00312,0 Hummm !!! \002\0034(∩_∩)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre une part de sa PizZa juste sortie du four \0034♨\00312 de \0033,3\[ \]\0030,0\[ \]\0030,4 Pizza Hut® \0030,0\[ \]\0033,3\[ \]\003\00312,0 à \0034$pseudo \00312!!! \002\0034(∩_∩)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (pizza)"}
	}
}

proc mms { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user\00312 mange des \0035\002M&M'\0031s®\0031 \002\0034(\0034m\0034)\0034 \002\0033(\0033m\0033)\0033 \002\0034(\0034m\0034)\0034 \002\00312(\00312m\00312)\0031 \002\00314(\00314m\00314)\00312 Mmmm C'est Vraiment Bon ! \002\0034 (｡●́‿●̀｡)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user\00312 donne des \0035\002M&M'\0031s®\0031 \002\0034(\0034m\0034)\0034 \002\0033(\0033m\0033)\0033 \002\0034(\0034m\0034)\0034 \002\00312(\00312m\00312)\0031 \002\00314(\00314m\00314)\00312 à \0034$pseudo \00312!! Va donc trier tes \0035M&M'\0031s\00312 ça t'occuperas ! \002\0034 ٩(×̯×)۶"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (mms)"}
	}
}

proc mars { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Une barre chocolatée ?\0037$user \00312se mange un \002\0034,1 MarS® \002\00312,0 et ça Repart !\0034\002 °\(^▿^)/"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre de bon coeur \00313❤\00312 une barre chocolatée \002\0034,1 MarS® \002\00312,0 à \0034$pseudo \00312, et ça Repart !\0034\002 °\(^▿^)/"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (mars)"}
	}
}

proc plouf { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Un petit plouf ?\0037$user \00312fait un plongeon dans la piscine pour se rafraichir!\0032\002 ._.·´¯(_..·´¯(_\0034 (^▿^)\0032..·´¯(_..·´¯(."
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312pousse \0034$pseudo \00312dans la piscine pour s'en débarasser\0037! PLOUF !!! \0032\002 ._.·´¯(_..·´¯(_\0034 t(>.<t)\0032..·´¯(_..·´¯(."
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (plouf)"}
	}
}

proc croissant { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312va se bouffer un croissant\00312 tout(e) seul(e)! \0034\002 (>‿◠)✌"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre à\0034 $pseudo \00312un croissant tout chaud ! \0034\002 (乂˘⌣˘)ノ\0034ヽ(ˆ⌣ˆ)ヾ"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (croissant)"}
	}
}

proc chocolatine { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312va manger une bonne Chocolatine ! (Et pas un pain au chocolat!) \0034\002 (>‿◠)✌"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre à \0034$pseudo \00312une Chocolatine toute chaude ! \0034\002 (乂˘⌣˘)ノ\0037 \0034ヽ(ˆ⌣ˆ)ヾ"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (chocolatine)"}
	}
}

proc patate { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est comme les Patates ! (il-elle) a la \0034FRITE\00312 aujourd'hui! \0034\002 (ړײ)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit : la difference entre\0034 $pseudo \00312et une patate, c'est que la patate au moins elle est cultivée! \0034\002 ☜(ˆ▽ˆ)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (patate)"}
	}
}

proc pouet { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312vient de lacher un \0034Pet !\0031 (._.)ᔆᵒʳʳᵞ\00312 comme ça tout le salon peut en profiter ! \0034\002(•̪(•̪●)̪●).｡oO( ... )"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312lance un pet \0031☁☁☁\00312 sur\0034 $pseudo (¤﹏¤) \00312ça pik!!! \0034\002 ☜(ˆ▽ˆ)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (pouet)"}
	}
}

proc oignon { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit: y'en a ils-elles sont tellement chiant(e), que quand ils-elles épluchent un oignon, c'est l'oignon qui pleure ! \0034(´∀`)Mdrr"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit que\0034 $pseudo \00312est tellement chiant(e), que quand il-elle épluche un oignon c'est l'oignon qui pleure ! \0034☜(´∀`)Mdrr"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (oignon)"}
	}
}

proc vent { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312c'est pris(e) un \0031≋\00312 vent\0031 ≋\00312! personne n'a répondu ! \0034\002(¬_¬”)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312 dit : Tu sens cet air frais ? c'est ça un \0031≋\00312vent\0031 ≋\00312! \0034 $pseudo \0034\002(¬_¬”)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (vent)"}
	}
}

proc ecran { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312se dit:\0034WAWWW \00312c'est vraiment super intéressant ce que je vois sur mon écran! (je fais semblant d'écouter...) \0034\002(O﹏o)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312C'est bizarre, mon écran ne m'affiche que des conneries, ha non, c'est\0034 $pseudo \00312qui parle ... \0034\002(O﹏o)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (ecran)"}
	}
}

proc boude { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312 fait la tête et va bouder dans son coin ! \002\0034(╥﹏╥) "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit à \0034$pseudo \00312 rhoooo c'est pas bien de bouder ! \002\0034(╥﹏╥) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (boude)"}
	}
}

proc gratte { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312se gratte le dos \0034ahahahah... ça démange ! \002\0034m(><)m	"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit à \0034$pseudo \00312 tu peux aller te gratter je pense ! \002\0034m(><)m  "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (gratte)"}
	}
}

proc popcorn { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312adore sort le popcorn, s'installe confortablement et observe ! \002\0034 (˚▽˚) "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre du popcorn à \0034$pseudo \00312, installe toi et regarde ! \002\0034 (˚▽˚) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (popcorn)"}
	}
}

proc shocked { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est choqué(e) en voyant ce qui se dit ! \002\0034(─‿‿─) "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est choqué(e) en voyant les propos de \0034$pseudo	\00312! \002\0034(─‿‿─) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (shocked)"}
	}
}

proc mariage { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est prêt(e) pour le MARIAGE ! \002\0034 ✿ ❀(っ◔◡◔)っ ❤ "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312 fait sa demande de mariage à \0034$pseudo\00312! ! \002\0034 ✿ ❀ (>‿♥) ❤❤❤ "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (mariage)"}
	}
}

proc bus { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\00312Oulala lala ! \0037$user \00312dit qu'un bus vient d'arriver ! \002\0034 ⚠ (☉̃ₒ☉) ⚠"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312dit à \0034$pseudo \00312, tu peux remonter dans le bus et aller jusqu'au prochain arrêt ? (merci)\002\0034 ⚠ (☉̃ₒ☉) ⚠	"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (bus)"}
	}
}

proc kebab { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312a faim, et va aller se manger un bon kebab !\002\0034 (>‿◠)✌ "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre un kebab à \0034$pseudo \00312, bon appetit !\002\0034 (>‿◠) "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (kebab)"}
	}
}

proc triste { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est triste !\002\0034 （ つ︣﹏╰） "
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312trouve que \0034$pseudo \00312est bien triste !\002\0034 （ つ︣﹏╰） "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (triste)"}
	}
}

proc vnr { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312est enervé(e) !\002\0034 (>‘o’)>"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312trouve que \0034$pseudo \00312est bien énervé(e) !\002\0034 (>‘o’)> "
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (vnr)"}
	}
}

proc gateau { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312va se manger une bonne part de gateau\00312 tout(e) seul(e) ! \0034\002 ≧✯◡✯≦✌"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre à \0034 $pseudo \00312une bonne part de gateau ! \0034\002 ≧✯◡✯≦✌"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (gateau)"}
	}
}

proc gaufre { chan user pseudo } {
	global Clara Admin
	if { $pseudo == "" } {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312va se bouffer une gaufre\00312 chocolat ? chantilly ? confiture ? \0034\002 (• ◡•)"
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $chan :\0037$user \00312offre à \0034 $pseudo \00312une gaufre ! \0034\002 (• ◡•)"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Clara Tool's : \0034$user (gaufre)"}
	}
}



##########################################
# --> Procedures des Commandes Privés <--#
##########################################


proc msg:join {chan user password} {
	global Clara Admin
	set arg [split $chan]
	set stop "0"
	if {$password eq "$Admin(password)"} {
		putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $user :AddChan : $chan"
		putdcc $Clara(idx) ":$Clara(pseudo) JOIN $chan"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Join : \0034$user " }
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $user :Accés Refusè."
	}
}

proc msg:part {chan user password} {
	global Clara Admin
	set arg [split $chan]
	set stop "0"
	if {$password eq "$Admin(password)"} {
		putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $user :DelChan : $chan"
		putdcc $Clara(idx) ":$Clara(pseudo) PART $chan"
		if {$Clara(console) eq "1"} { putdcc $Clara(idx) ":$Clara(pseudo) PRIVMSG $Clara(salon) :\00312Part : \0034$user " }
	} else {
		putdcc $Clara(idx) ":$Clara(pseudo) NOTICE $user :Accès Refusè."
	}
}

set Clara(putlog) "Clara Service v1.0a par Chris - Yeh"
