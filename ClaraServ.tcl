#############################################################################
#  ██████╗██╗      █████╗ ██████╗  █████╗ ███████╗███████╗██████╗ ██╗   ██╗ #
# ██╔════╝██║     ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║ #
# ██║     ██║     ███████║██████╔╝███████║███████╗█████╗  ██████╔╝██║   ██║ #
# ██║     ██║     ██╔══██║██╔══██╗██╔══██║╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝ #
# ╚██████╗███████╗██║  ██║██║  ██║██║  ██║███████║███████╗██║  ██║ ╚████╔╝  #
#  ╚═════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝   #
#############################################################################
#
#	Auteur	:
#		-> ZarTek (ZarTek.Creole@GMail.Com)
#
#	Website	:
#		-> github.com/ZarTek-Creole/TCL-ClaraServ
#
#	Support	:
#		-> github.com/ZarTek-Creole/TCL-ClaraServ/issues
#
#	Docs	:
#		-> github.com/ZarTek-Creole/TCL-ClaraServ/wiki
#
#   DONATE   :
#       -> https://github.com/ZarTek-Creole/DONATE
#
#	LICENSE :
#		-> Creative Commons Attribution 4.0 International
#		-> github.com/ZarTek-Creole/TCL-ClaraServ/blob/main/LICENSE.txt
#
#	Greet	:
#		-> Chris et Yeh pour versions antérieures
#		-> Amandine de www.eggdrop.fr pour les testes, les idées, ...
#		-> MenzAgitat de www.eggdrop.fr pour ses astuces/conseils
#
#############################################################################

namespace eval ClaraServ {
	variable config
	variable UID_DB
	variable CONNECT_ID
	variable BOT_ID
	variable DIR
	variable SCRIPT

	set DIR(CUR)			[file dirname [file dirname [file normalize [file join [info script] ...]]]]
	set CONNECT_ID			{}
	set BOT_ID				{}
	array set SCRIPT {
		"name"		"ClaraServ Service"
		"version"	"1.1.20220622"
		"auteur"	"ZarTek"
		"need_zct"	"0.0.1"
		"need_ircs"	"0.0.4"
	}
	set config(path_script)	[file dirname [info script]];

	set config(db_list)		[list \
								"salon.db"
							];

	set config(vars_list)	[list	\
								"uplink_host"		\
								"uplink_port"		\
								"uplink_password"	\
								"serverinfo_name"	\
								"serverinfo_descr"	\
								"serverinfo_id"		\
								"uplink_useprivmsg"	\
								"uplink_debug"		\
								"service_nick"		\
								"service_user"		\
								"service_host"		\
								"service_gecos"		\
								"service_modes"		\
								"service_channel"	\
								"service_chanmodes"	\
								"service_usermodes"	\
								"admin_password"	\
								"db_lang"			\
								"admin_console"		\
								"db_lang"
							];
	if { [file exists ${::ClaraServ::DIR(CUR)}/TCL-ZCT/ZCT.tcl] } { catch { source ${::ClaraServ::DIR(CUR)}/TCL-ZCT/ZCT.tcl } }
	if { [catch { package require ZCT ${SCRIPT(need_zct)} } ] } {
		die "\[${SCRIPT(name)} - erreur\] Nécessite le package ZCT ${SCRIPT(need_zct)} (ou plus) pour fonctionner, Télécharger sur 'https://github.com/ZarTek-Creole/TCL-ZCT'. Le chargement du script a été annulé." ;
	} else { namespace import -force ::ZCT::* }

	# Si le dossier et fichier IRCServices sont existante dans le dossier courant, on le charge.
	if { [file exists "${::ClaraServ::DIR(CUR)}/TCL-PKG-IRCServices/ircservices.tcl"] } {
		source "${::ClaraServ::DIR(CUR)}/TCL-PKG-IRCServices/ircservices.tcl"
	}
	pkg load IRCServices ${SCRIPT(need_ircs)} ${SCRIPT(name)}
	
	if {[info commands ::ClaraServ::uninstall] eq "::ClaraServ::uninstall" } { ::ClaraServ::uninstall }
	namespace eval FCT {
		namespace export CONNECT_ID
		namespace export BOT_ID
		
	}
	proc uninstall {args} {
		variable config
		variable SCRIPT

		putlog "Désallocation des ressources de \002[set SCRIPT(name)]\002..."

		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		
		# Arrêt des timers en cours.
		foreach running_timer [timers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_timer 1]] } { killtimer [lindex $running_timer 2] }
		}
		namespace delete ::ClaraServ
	}
}
proc ::ClaraServ::INIT { } {
	variable config
	variable database
	variable SCRIPT
	#################
	# ClaraServ Fichier #
	#################
	if { ![file isdirectory "[::ClaraServ::FCT::Get:ScriptDir "db"]"] } { file mkdir "[::ClaraServ::FCT::Get:ScriptDir "db"]" }

	################
	# ClaraServ Source #
	################
	if { [file exists [::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf] } {
		if { [ catch { source [::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf } err ] } { 
			putlog "\[ Erreur \] Probleme de chargement de '[::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf': $err"
			exit
		} 
		::ClaraServ::FCT::Check:Config
	} else {
		if { [file exists [::ClaraServ::FCT::Get:ScriptDir]ClaraServ.Example.conf] } {
			putlog "Editez, configurer et renomer 'ClaraServ.Example.conf' en 'ClaraServ.conf' dans '[::ClaraServ::FCT::Get:ScriptDir]'"
			exit
		} else {
			putlog "Fichier de configuration '[::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf' manquant."
			exit
		}
	}

	set config(FILE_DB)	"database.[string tolower $config(db_lang)].db"
	# generer les db si elle n'existe pas
	::ClaraServ::FCT::DB:INIT [list  {*}$config(db_list) {*}$config(FILE_DB)]

	if { [file exists [::ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)}] } {
		if { [ catch { source [::ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)} } err ] } { 
			putlog "\[ Erreur \] Probleme de chargement de '[::ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)}': $err"
			exit
		} 
	} else {
		putlog "Fichier de base de données '[::ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)}' manquant."
		exit
	}
	
	if {![info exists config(idx)]} { ::ClaraServ::FCT::Socket:Connexion }
	putlog "\[[set SCRIPT(name)] - Chargement\]\003 v[set SCRIPT(version)] par [set SCRIPT(auteur)] charger."
}

###################
# ClaraServ fonctions #
###################
proc ::ClaraServ::FCT::Get:ScriptDir { {DIR ""} } {
	global ::ClaraServ::config
	return "[file normalize $config(path_script)/$DIR]/"
}

proc ::ClaraServ::FCT::Check:Config { } {
	global ::ClaraServ::config
	foreach CONF $config(vars_list) {
		if { ![info exists config($CONF)] } {
			putlog "\[ Erreur \] Configuration de ClaraServ Service Incorrecte... '$CONF' Paramettre manquant"
			exit
		}
		if { $config($CONF) == "" } {
			putlog "\[ Erreur \] Configuration de ClaraServ Service Incorrecte... '$CONF' Valeur vide"
			exit
		}
	}
}

proc ::ClaraServ::FCT::substitute_special_vars_2nd_pass {chan text} {
	global ::ClaraServ::config
	# regsub -all %idle_time% $text [::reanimator::idle_time $chan] text
	# regsub -all %lastnick% $text [regsub -all {\W} [lindex $::reanimator::memory([md5 $chan]) 1] {\\&}] text
	regsub -all %chan%			$text [regsub -all {[\[\]\{\}\$\"\\]} $chan {\\&}] text ; # "
	regsub -all %botnick%		$text [regsub -all {\W} $config(service_nick) {\\&}] text
	regsub -all %hour%			$text [set hour [strftime %H [unixtime]]] text
	regsub -all %hour_short%	$text [if { $hour != 00 } { set dummy [string trimleft $hour 0] } { set dummy 0 }] text
	regsub -all %minutes%		$text [set minutes [strftime %M [unixtime]]] text
	regsub -all %minutes_short%	$text [if { $minutes != 00 } { set dummy [string trimleft $minutes 0] } { set dummy 0 }] text
	regsub -all %seconds%		$text [set seconds [strftime %S [unixtime]]] text
	regsub -all %seconds_short%	$text [if { $seconds != 00 } { set dummy [string trimleft $seconds 0] } { set dummy 0 }] text
	regsub -all %day_num%		$text [strftime %d [unixtime]] text
	regsub -all %day%			$text [string map -nocase {Mon lundi Tue mardi Wed mercredi Thu jeudi Fri vendredi Sat samedi Sun dimanche} [strftime "%a" [unixtime]]] text
	regsub -all %month_num%		$text [strftime %m [unixtime]] text
	regsub -all %month%			$text [string map {Jan janvier Feb février Mar mars Apr avril May mai Jun juin Jul juillet Aou août Sep septembre Oct octobre Nov novembre Dec décembre} [strftime %b [unixtime]]] text
	regsub -all %year%			$text [strftime %Y [unixtime]] text
	return $text
}
proc ::ClaraServ::FCT::DB:GET { CMD NIVEAU } {
	global ::ClaraServ::database
	foreach index [lsearch -all -nocase $database "*$CMD*"] {
		set index_data	[lindex $database $index]
		set type		[lindex $index_data 1]
		set data		[lindex $index_data 2]
		if { $type == $NIVEAU } {
			return $data
		}
	}
	return -1
}
proc ::ClaraServ::FCT::DB:CMD:LIST { } {
	global ::ClaraServ::database
	set ltext		[llength $database];
	set text		[lindex $database 0];
	set CMD_LIST	[list];
	set x			0;
	while { $x < $ltext } {
		lappend CMD_LIST [lindex [lindex $database $x] 0]
		incr x
	}
	return [lsort -unique $CMD_LIST]
}

proc ::ClaraServ::FCT::SENT:NOTICE { DEST MSG } {
	variable BOT_ID
	$BOT_ID	notice $DEST [::ClaraServ::FCT::apply_visuals $MSG]
}

proc ::ClaraServ::FCT::SENT:PRIVMSG { DEST MSG } {
	variable BOT_ID
	$BOT_ID	privmsg $DEST [::ClaraServ::FCT::apply_visuals $MSG]
}
proc ::ClaraServ::FCT::SENT:MSG:TO:USER { DEST MSG } {
	global ::ClaraServ::config
	if { $config(uplink_useprivmsg) == 1 } {
		::ClaraServ::FCT::SENT:PRIVMSG $DEST $MSG;
	} else {
		::ClaraServ::FCT::SENT:NOTICE $DEST $MSG;
	}
}
proc ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG { MSG } {
	global ::ClaraServ::config
	::ClaraServ::FCT::SENT:PRIVMSG $config(service_channel) $MSG;
}

proc ::ClaraServ::FCT::DB:INIT { LISTDB } {
	foreach DB_FILE_NAME [split $LISTDB] {
		if { ![file exists "[::ClaraServ::FCT::Get:ScriptDir "db"]${DB_FILE_NAME}"] } {
			set FILE_PIPE	[open "[::ClaraServ::FCT::Get:ScriptDir "db"]${DB_FILE_NAME}" a+];
			close $FILE_PIPE
		}
	}
}
###############################################################################
### Substitution des symboles couleur/gras/soulignement/...
###############################################################################
# Modification de la fonction de MenzAgitat
# <cXX> : Ajouter un Couleur avec le code XX : <c01>; <c02,01>
# </c>  : Enlever la Couleur (refermer la deniere declaration <cXX>) : </c>
# <b>   : Ajouter le style Bold/gras
# </b>  : Enlever le style Bold/gras
# <u>   : Ajouter le style Underline/souligner
# </u>  : Enlever le style Underline/souligner
# <i>   : Ajouter le style Italic/Italique
# <s>   : Enlever les styles precedent
proc ::ClaraServ::FCT::apply_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "\003\\1" data
	regsub -all -nocase {<b>|</b>} $data "\002" data
	regsub -all -nocase {<u>|</u>} $data "\037" data
	regsub -all -nocase {<i>|</i>} $data "\026" data
	return [regsub -all -nocase {<s>} $data "\017"]
}
proc ::ClaraServ::FCT::Remove_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "" data
	regsub -all -nocase {<b>|</b>} $data "" data
	regsub -all -nocase {<u>|</u>} $data "" data
	regsub -all -nocase {<i>|</i>} $data "" data
	return [regsub -all -nocase {<s>} $data ""]
}

proc ::ClaraServ::FCT::TXT:ESPACE:DISPLAY { text length } {
	set text			[string trim $text]
	set text_length		[string length $text];
	set espace_length	[expr ($length - $text_length)/2.0]
	set ESPACE_TMP		[split $espace_length .]
	set ESPACE_ENTIER	[lindex $ESPACE_TMP 0]
	set ESPACE_DECIMAL	[lindex $ESPACE_TMP 1]
	if { $ESPACE_DECIMAL == 0 } {
		set espace_one			[string repeat " " $ESPACE_ENTIER];
		set espace_two			[string repeat " " $ESPACE_ENTIER];
		return "$espace_one$text$espace_two"
	} else {
		set espace_one			[string repeat " " $ESPACE_ENTIER];
		set espace_two			[string repeat " " [expr ($ESPACE_ENTIER+1)]];
		return "$espace_one$text$espace_two"
	}

}

proc ::ClaraServ::FCT::CMD:LOG { cmd sender } {
	global ::ClaraServ::config
	if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Commandes :<c04>  $cmd <c12>par<c04> $sender"  }
}

proc ::ClaraServ::FCT::CMD:SHOW:LIST { DEST } {
	set max				8;
	set l_espace		13;
	set CMD_LIST		""
	foreach CMD [::ClaraServ::FCT::DB:CMD:LIST] {
		lappend CMD_LIST	"<c04>[::ClaraServ::FCT::TXT:ESPACE:DISPLAY $CMD $l_espace]<c12>"
		if { [incr i] > $max-1 } {
			unset i
		::ClaraServ::FCT::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
			set CMD_LIST	""
		}
	}
	::ClaraServ::FCT::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
	::ClaraServ::FCT::SENT:MSG:TO:USER $DEST "<c>";
}

proc ::ClaraServ::FCT::DB:DATA:EXIST { DB DATA } {
	set DB_FILE		"[::ClaraServ::FCT::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist $DB_FILE] } { return "-1"; }
	set FILE_PIPE	[open $DB_FILE r];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA $FILE_DATA] } {
			close $FILE_PIPE;
			return 1;
		}
	}
	close $FILE_PIPE;
	return 0;
}

proc ::ClaraServ::FCT::DB:SALON:ADD { SALON } {
	if { [string index $SALON 0] != "#" } { return 0; }
	if { [::ClaraServ::FCT::DB:DATA:EXIST "salon" $SALON] == 0 } {
		set DB_FILE		"[::ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
		set FILE_PIPE	[open $DB_FILE a];
		puts $FILE_PIPE $SALON;
		close $FILE_PIPE;
		return 1;
	} else {
		return -1;
	}
}

proc ::ClaraServ::FCT::DB:DATA:REMOVE { DB DATA } {
	set DB_FILE			"[::ClaraServ::FCT::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist $DB_FILE] } { return "-1"; }
	set FILE_PIPE		[open $DB_FILE r];
	set STATE			0;
	set FILE_NEW_DATA	[list];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA $FILE_DATA] } {
			set STATE		1;
		} elseif { $FILE_DATA != "" } {
			lappend FILE_NEW_DATA $FILE_DATA;
		}
	}
	close $FILE_PIPE
	set FILE_PIPE		[open $DB_FILE w+];
	foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
	close $FILE_PIPE
	return $STATE;
}
####################
#--> Procedures <--#
####################
proc ::ClaraServ::FCT::Socket:Connexion {} {
	global ::ClaraServ::config
	variable CONNECT_ID
	variable BOT_ID
	
	if { $config(uplink_ssl) == 1		} { set config(uplink_port) "+$config(uplink_port)" }
	if { $config(serverinfo_id) != ""	} { set config(uplink_ts6) 1 } else { set config(uplink_ts6) 0 }
	
	set CONNECT_ID [::IRCServices::connection]; # Creer une instance services
	$CONNECT_ID connect $config(uplink_host) $config(uplink_port) $config(uplink_password) $config(uplink_ts6) $config(serverinfo_name) $config(serverinfo_id); # Connexion de l'instance service
	if { $config(uplink_debug) == 1} { $CONNECT_ID config logger 1; $CONNECT_ID config debug 1; }

	set BOT_ID [$CONNECT_ID bot]; #Creer une instance bot dans linstance services
	
	$BOT_ID create $config(service_nick) $config(service_user) $config(service_host) $config(service_gecos) $config(service_modes); # Creation d'un bot service
	$BOT_ID join $config(service_channel)
	$BOT_ID registerevent EOS {
		global ::ClaraServ::config
		[sid] mode $config(service_channel) $config(service_chanmodes)
		if { $config(service_usermodes) != "" } { 
			[sid] mode $config(service_channel) $config(service_usermodes) $config(service_nick)
		}
		set fichier(salon) "[::ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
		set fp	[open $fichier(salon) "r"]
		set fc	-1
		while {![eof $fp]} {
			set data	[gets $fp]
			incr fc
			if { $data !="" } {
				[bid] join $data
				if { $config(service_usermodes) != "" } { 
					[sid] mode $data $config(service_usermodes) $config(service_nick)
				}
			}
			unset data
		}
		close $fp
		
	}
	$BOT_ID registerevent PRIVMSG {
		set cmd		[lindex [msg] 0]
		set data	[lrange [msg] 1 end]
		##########################
		#--> Commandes Privés <--#
		##########################
		# si [target] ne commence pas par # c'est un pseudo
		if { [string index [target] 0] != "#"} {
			if { $cmd == "join"		}	{ 
				# [22:50:42] Received: :001119S0G PRIVMSG 00CAAAAAB :join
				::ClaraServ::IRC:CMD:PRIV:JOIN [who2] [target] $cmd $data 
			}
			if { $cmd == "part"		}	{ 
				# [21:49:04] Received: :001119S0G PRIVMSG 00CAAAAAB :part
				::ClaraServ::IRC:CMD:PRIV:PART [who2] [target] $cmd $data 
			}
			if { $cmd == "help"		}	{ 
				# [21:49:04] Received: :001119S0G PRIVMSG 00CAAAAAB :part
				::ClaraServ::IRC:CMD:PRIV:HELP [who2] [target] $cmd $data 
			}
		}
		##########################
		#--> Commandes Salons <--#
		##########################
		# si [target] commence par # c'est un salon
		if { [string index [target] 0] == "#"} {
			if { $cmd == "!cmds"	}	{ 
				# [22:10:39] Received: :ZarTek PRIVMSG #Eva :!cmds
			::ClaraServ::IRC:CMD:PUB:CMDS [who] [target] $cmd $data 
			}
			if { $cmd == "!help"	}	{ 
				# Received: :ZarTek PRIVMSG #Eva :!help
				::ClaraServ::IRC:CMD:PUB:HELP [who] [target] $cmd $data 
			}
			if { $cmd == "!random"	}	{
				# [22:10:04] Received: :ZarTek PRIVMSG #Eva :!random
				 ::ClaraServ::IRC:CMD:PUB:RANDOM [who] [target] $cmd $data
			}
			# Nous verifions si la commande corresponds a une commandes de la database:
			if { [lsearch -nocase [::ClaraServ::FCT::DB:CMD:LIST] $cmd] != "-1" } {
				if { [catch {ClaraServ::IRC:CMD:PUB:DYNAMIC [who] [target] $cmd $data } error] } {
				::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "\[ERROR\] CMD: $cmd - Error: $error"
				}
			}
		}
	}; # Creer un event sur PRIVMSG
	
}
#######################
#  --> Commandes <--  #
#######################
proc ::ClaraServ::IRC:CMD:PRIV:HELP { sender destination cmd data } {
	::ClaraServ::IRC:CMD:PUB:HELP $sender $destination $cmd $data
}
proc ::ClaraServ::IRC:CMD:PUB:HELP { sender destination cmd data } {
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Aide publique<c04> :."
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> !help   - <c06>  Affiche cette aide"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> !cmds   - <c06>  Affiche la list des commandes"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> !random - <c06>  Affiche un text aleatoire"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Aide privé<c04> :."
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> help    - <c06>  Affiche cette aide"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> join    - <c06>  faire joindre un salon"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> part    - <c06>  faire quitter un salon"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	::ClaraServ::FCT::CMD:LOG $cmd $sender
}
proc ::ClaraServ::IRC:CMD:PUB:RANDOM { sender destination cmd data } {
	variable config
	set CMD_RANDOM	[lindex [::ClaraServ::FCT::DB:CMD:LIST] [rand [llength [::ClaraServ::FCT::DB:CMD:LIST]]]]
	if { [catch {ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $CMD_RANDOM $data } error] } {
		::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "\[ERROR\] CMD: $cmd - Error: $error"
	}
}
proc ::ClaraServ::IRC:CMD:PUB:DYNAMIC { sender destination cmd pseudo } {
	if { $pseudo == "" } {
		set data [::ClaraServ::FCT::DB:GET $cmd 0];
	} else {
		set data [::ClaraServ::FCT::DB:GET $cmd 1];
	}
	if { $data != "-1" } {
		set data	[::ClaraServ::FCT::substitute_special_vars_2nd_pass $destination $data];
		set data	[string map -nocase [list "%pseudo%" "$pseudo" "%sender%" "$sender" "%destination%" "$destination"] $data]
		::ClaraServ::FCT::SENT:PRIVMSG $destination $data
	}
	::ClaraServ::FCT::CMD:LOG "!random" $sender
}

proc ::ClaraServ::IRC:CMD:PUB:CMDS { sender destination cmd data } {
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Liste des commandes d'animation<c04> :."
	::ClaraServ::FCT::CMD:SHOW:LIST $sender
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Autre<c04> :."
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c12>!help    </c>-<c04> Affiche l'aide"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c12>!random  </c>-<c04> Affiche un text aleatoire"
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04>  * <b>Note:</b> Il y a certaine commandes qui ne sont pas activées sur tous les salons."
	::ClaraServ::FCT::CMD:LOG $cmd $sender 
}
##########################################
# --> Procedures des Commandes Privés <--#
##########################################
proc ::ClaraServ::IRC:CMD:PRIV:JOIN { sender destination cmd data } {
	variable config
	variable ::ClaraServ::FCT::BOT_ID
	set chan		[lindex $data 0]
	set password	[lindex $data 1]
	if { $password == "" } {
		::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Mauvaise syntaxe: /msg $config(service_nick) join #salon admin_password"
	} elseif { $password eq "$config(admin_password)" } {
		if { [::ClaraServ::FCT::DB:SALON:ADD $chan] == 1} {
			$BOT_ID join $chan
			$BOT_ID mode $chan +$config(service_usermodes) $config(service_nick)
			::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "AddChan : $chan"
			if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Join :<c04> $chan </c>par <c04>$sender "  }
		} else {
		::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "AddChan : $chan | Erreur Non ajouter "
			if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Join :<c04> $chan </c>par <c04>$sender | Erreur Non ajouter " }
		}

	} else {
		::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Accés Refusè."
		if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Join :<c04> $chan </c>par <c04>$sender </c>-><c04> Accés Refusè."  }
	}
}

proc ::ClaraServ::IRC:CMD:PRIV:PART { sender destination cmd data } {
	variable config
	variable ::ClaraServ::FCT::BOT_ID
	# /msg clara part #salon lepassquetamisenconf
	set chan		[lindex $data 0]
	set password	[lindex $data 1]
	if { $password == "" } {
		::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Mauvaise syntaxe: /msg $config(service_nick) part #salon admin_password"
	} elseif { $password eq "$config(admin_password)" } {
		if { [string match -nocase $config(service_channel) $chan] } {
			::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "DelChan : $chan | Erreur: impossible $config(service_channel) est le salon de logs."
			if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>$sender  | Erreur: impossible $config(service_channel) est le salon de logs." }
		} elseif { [::ClaraServ::FCT::DB:DATA:REMOVE "salon" $chan] == 1 } {
			$BOT_ID part $chan
			::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "DelChan : $chan"
			if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>$sender "  }
		} else {
			::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "DelChan : $chan | Erreur Non ajouter "
			if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>$sender | Erreur Non suprimer " }
		}


	} else {
		::ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Accés Refusè."
		if {$config(admin_console) eq "1"} { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>$sender </c>-><c04> Accés Refusè."  }
	}
}

::ClaraServ::INIT
