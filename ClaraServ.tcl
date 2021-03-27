#############################################################################
##-->						TCL ClaraServ Service						<--##
#---------------------------------------------------------------------------#
## Auteur	: MalaGaM
## Website	: https://github.com/MalaGaM/TCL-ClaraServ-Service
## Support	: https://github.com/MalaGaM/TCL-ClaraServ-Service/issues
##
## Greet	:
##		-> Chris et Yeh pour versions antérieures
##		-> Amandine de www.eggdrop.fr pour les testes, les idées, ...
##		-> MenzAgitat de www.eggdrop.fr pour ses astuces/conseils
#############################################################################
if {[info commands ::ClaraServ::uninstall] eq "::ClaraServ::uninstall" } { ::ClaraServ::uninstall }
namespace eval ClaraServ {
	variable config
	variable UID_DB

	set config(scriptname)	"ClaraServ Service"
	set config(version)		"1.1.20210326"
	set config(auteur)		"MalaGaM"
	
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
								"db_lang"			\
								"scriptname"		\
								"version"			\
								"auteur"
							];
	namespace eval FCT {

	}
	proc uninstall {args} {
		variable config

		putlog "Désallocation des ressources de \002[set config(scriptname)]\002..."

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
proc ClaraServ::INIT { } {
	variable config
	variable database
	#################
	# ClaraServ Fichier #
	#################
	if { [file isdirectory "[ClaraServ::FCT::Get:ScriptDir "db"]"] } { file mkdir "[ClaraServ::FCT::Get:ScriptDir "db"]" }

	################
	# ClaraServ Source #
	################
	if { [file exists [ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf] } {
		source [ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf
		ClaraServ::FCT::Check:Config
	} else {
		if { [file exists [ClaraServ::FCT::Get:ScriptDir]ClaraServ.Example.conf] } {
			putlog "Editez, configurer et renomer 'ClaraServ.Example.conf' en 'ClaraServ.conf' dans '[ClaraServ::FCT::Get:ScriptDir]'"
			exit
		} else {
			putlog "Fichier de configuration '[ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf' manquant."
			exit
		}
	}

	set config(FILE_DB)	"database.[string tolower $config(db_lang)].db"
	# generer les db si elle n'existe pas
	ClaraServ::FCT::DB:INIT [list $config(db_list) $config(FILE_DB)]

	if { [file exists [ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)}] } {
		source [ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)}
	} else {
		putlog "Fichier de base de données '[ClaraServ::FCT::Get:ScriptDir "db"]/${config(FILE_DB)}' manquant."
		exit
	}
	
	if {![info exists config(idx)]} { ClaraServ::FCT::Socket:Connexion }
	set config(putlog) "[set config(scriptname)] v[set config(version)] par [set config(auteur)]"
}

###################
# ClaraServ fonctions #
###################
proc ClaraServ::FCT::Get:ScriptDir { {DIR ""} } {
	global ClaraServ::config
	return "[file normalize $config(path_script)/$DIR]/"
}

proc ClaraServ::FCT::Check:Config { } {
	global ClaraServ::config
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

proc ClaraServ::FCT::substitute_special_vars_2nd_pass {chan text} {
	global ClaraServ::config
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
proc ClaraServ::FCT::DB:GET { CMD NIVEAU } {
	global ClaraServ::database
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
proc ClaraServ::FCT::DB:CMD:LIST { } {
	global ClaraServ::database
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

proc ClaraServ::FCT::SENT:NOTICE { DEST MSG } {
	global ClaraServ::config
	ClaraServ::FCT::Socket:Sent ":$config(service_nick) NOTICE $DEST :[ClaraServ::FCT::apply_visuals $MSG]"
}

proc ClaraServ::FCT::SENT:PRIVMSG { DEST MSG } {
	global ClaraServ::config
	ClaraServ::FCT::Socket:Sent ":$config(service_nick) PRIVMSG $DEST :[ClaraServ::FCT::apply_visuals $MSG]"
}
proc ClaraServ::FCT::SENT:MSG:TO:USER { DEST MSG } {
	global ClaraServ::config
	if { $config(uplink_useprivmsg) == 1 } {
		ClaraServ::FCT::SENT:PRIVMSG $DEST $MSG;
	} else {
		ClaraServ::FCT::SENT:NOTICE $DEST $MSG;
	}
}
proc ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG { MSG } {
	global ClaraServ::config
	ClaraServ::FCT::SENT:PRIVMSG $config(service_channel) $MSG;
}

proc ClaraServ::FCT::DB:INIT { LISTDB } {
	foreach DB_FILE_NAME $LISTDB {
		if { ![file exists "[ClaraServ::FCT::Get:ScriptDir "db"]${DB_FILE_NAME}"] } {
			set FILE_PIPE	[open "[ClaraServ::FCT::Get:ScriptDir "db"]${DB_FILE_NAME}" a+];
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
proc ClaraServ::FCT::apply_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "\003\\1" data
	regsub -all -nocase {<b>|</b>} $data "\002" data
	regsub -all -nocase {<u>|</u>} $data "\037" data
	regsub -all -nocase {<i>|</i>} $data "\026" data
	return [regsub -all -nocase {<s>} $data "\017"]
}
proc ClaraServ::FCT::Remove_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "" data
	regsub -all -nocase {<b>|</b>} $data "" data
	regsub -all -nocase {<u>|</u>} $data "" data
	regsub -all -nocase {<i>|</i>} $data "" data
	return [regsub -all -nocase {<s>} $data ""]
}

proc ClaraServ::FCT::TXT:ESPACE:DISPLAY { text length } {
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

proc ClaraServ::FCT::Socket:Sent { arg } {
	global ClaraServ::config
	if { $config(uplink_debug) == 1 } {
		putlog "Sent: $arg"
	}
	putdcc $config(idx) $arg
}

proc ClaraServ::FCT::CMD:LOG { cmd sender } {
	global ClaraServ::config
	if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Commandes :<c04>  $cmd <c12>par<c04> $sender"  }
}

proc ClaraServ::FCT::CMD:LOG { cmd sender } {
	global ClaraServ::config
	if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Commandes :<c04>  $cmd <c12>par<c04> $sender"  }
}

proc ClaraServ::FCT::CMD:SHOW:LIST { DEST } {
	set max				8;
	set l_espace		13;
	set CMD_LIST		""
	foreach CMD [ClaraServ::FCT::DB:CMD:LIST] {
		lappend CMD_LIST	"<c04>[ClaraServ::FCT::TXT:ESPACE:DISPLAY $CMD $l_espace]<c12>"
		if { [incr i] > $max-1 } {
			unset i
			ClaraServ::FCT::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
			set CMD_LIST	""
		}
	}
	ClaraServ::FCT::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
	ClaraServ::FCT::SENT:MSG:TO:USER $DEST "<c>";
}

proc ClaraServ::FCT::DATA:TO:NICK { DATA } {
	if { [string range $DATA 0 0] == 0 } {
		set user		[ClaraServ::FCT::UID:CONVERT $DATA]
	} else {
		set user		$DATA
	}
	return $user;
}

proc ClaraServ::FCT::UID:CONVERT { ID } {
	global ClaraServ::UID_DB
	if { [info exists UID_DB([string toupper $ID])] } {
		return "$UID_DB([string toupper $ID])"
	} else {
		return $ID
	}
}

proc ClaraServ::FCT::DB:DATA:EXIST { DB DATA } {
	set DB_FILE		"[ClaraServ::FCT::Get:ScriptDir "db"]/${DB}.db"
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

proc ClaraServ::FCT::DB:SALON:ADD { SALON } {
	if { [string index $SALON 0] != "#" } { return 0; }
	if { [ClaraServ::FCT::DB:DATA:EXIST "salon" $SALON] == 0 } {
		set DB_FILE		"[ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
		set FILE_PIPE	[open $DB_FILE a];
		puts $FILE_PIPE $SALON;
		close $FILE_PIPE;
		return 1;
	} else {
		return -1;
	}
}

proc ClaraServ::FCT::DB:DATA:REMOVE { DB DATA } {
	set DB_FILE			"[ClaraServ::FCT::Get:ScriptDir "db"]/${DB}.db"
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
proc ClaraServ::FCT::Socket:Connexion {} {
	global ClaraServ::config
	if { ![catch "connect $config(uplink_host) $config(uplink_port)" config(idx)] } {
		set config(init)			1;
		if { $config(uplink_debug) == 1 } { putlog "Successfully connected to uplink $config(uplink_host) $config(uplink_port)" }
		if { $config(serverinfo_id) == "" } {
			ClaraServ::FCT::Socket:Sent "PASS $config(uplink_password)"
			ClaraServ::FCT::Socket:Sent "SERVER $config(serverinfo_name) 1 :$config(serverinfo_descr)"

			ClaraServ::FCT::Socket:Sent ":$config(serverinfo_name) NICK $config(service_nick) 1 [unixtime] $config(service_user) $config(service_host) $config(serverinfo_name) :$config(service_gecos)"

			ClaraServ::FCT::Socket:Sent ":$config(serverinfo_name) MODE $config(service_nick) $config(service_modes)"
			ClaraServ::FCT::Socket:Sent ":$config(service_nick) JOIN $config(service_channel)"
			set fichier(salon) "[ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
			set fp [open $fichier(salon) "r"]
			set fc -1
			while {![eof $fp]} {
				set data [gets $fp]
				incr fc
				if {$data !=""} {
					ClaraServ::FCT::Socket:Sent ":$config(service_nick) JOIN $data"
				}
				unset data
			}
			close $fp
		} {
			ClaraServ::FCT::Socket:Sent "PASS :$config(uplink_password)"
			ClaraServ::FCT::Socket:Sent "PROTOCTL NICKv2 VHP UMODE2 NICKIP SJOIN SJOIN2 SJ3 NOQUIT TKLEXT MLOCK SID"
			ClaraServ::FCT::Socket:Sent "PROTOCTL EAUTH=$config(serverinfo_name),,,ClaraServ-$config(version)"
			ClaraServ::FCT::Socket:Sent "PROTOCTL SID=$config(serverinfo_id)"
			ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) SERVER $config(serverinfo_name) 1 :Services for IRC Networks"
			set config(server_id)		[string toupper	"${config(serverinfo_id)}AAAAAB"]
		}
		control $config(idx) ClaraServ::Socket:Event;
		utimer 30 ClaraServ::FCT::Socket:Verification
	} else {
		putlog "La connection échoué de ClaraServ a $config(uplink_host) $config(uplink_port)"
		exit
	}
}
###################
# ClaraServ Connexion #
###################

proc ClaraServ::Server:Connexion { } {
	variable config
	ClaraServ::FCT::Socket:Sent "EOS"
	ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) SQLINE $config(service_nick) :Reserved for services"
	ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) UID $config(service_nick) 1 [unixtime] $config(service_user) $config(service_host) $config(server_id) * +qioS * * * :$config(service_gecos)"
	ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) SJOIN [unixtime] $config(service_channel) + :$config(server_id)"
	ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) MODE $config(service_channel) $config(service_chanmodes)"
	if { $config(service_usermodes) != "" } { 
		ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) MODE $config(service_channel) $config(service_usermodes) $config(service_nick)"
	}
	set fichier(salon) "[ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
	set fp	[open $fichier(salon) "r"]
	set fc	-1
	while {![eof $fp]} {
		set data	[gets $fp]
		incr fc
		if { $data !="" } {
			ClaraServ::FCT::Socket:Sent ":$config(service_nick) JOIN $data"
			if { $config(service_usermodes) != "" } { 
				ClaraServ::FCT::Socket:Sent ":$config(serverinfo_id) MODE $data $config(service_usermodes) $config(service_nick)" 
			}
		}
		unset data
	}
	close $fp
}

######################
#--> Verification <--#
######################
proc ClaraServ::FCT::Socket:Verification {} {
	global ClaraServ::config
	if {[valididx $config(idx)]} { utimer 30 ClaraServ::FCT::Socket:Verification } else { ClaraServ::FCT::Socket:Connexion }
}

proc ClaraServ::Socket:Event { idx arg } {
	global ClaraServ::config
	global ClaraServ::UID_DB

	if { $config(uplink_debug) == 1 } { putlog "Received: $arg" }
	switch -exact [lindex "$arg" 0] {
		"PING" {
			ClaraServ::FCT::Socket:Sent "PONG [lindex $arg 1]"
		}
		"NETINFO" {
			set config(netinfo)		[lindex $arg 4]
			set config(network)		[lindex $arg 8]
			ClaraServ::FCT::Socket:Sent "NETINFO 0 [unixtime] 0 $config(netinfo) 0 0 0 $config(network)"
		}
		"SQUIT" {
			set serv		[lindex $arg 1]
			ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c>$config(console_com)Unlink <c>$config(console_deco):<c>$config(console_txt) $serv"
		}
		"SERVER" {
			# Received: SERVER irc.xxx.net 1 :U5002-Fhn6OoEmM-001 Serveur networkname
			if { $config(init) == 1 } {
				ClaraServ::Server:Connexion
			}
		}

	}
	switch -exact [lindex $arg 1] {
		"PRIVMSG" {
			#[23:35:52] cmd(!7up) chan(!7up) user(MalaGaM) pseudo()

			set sender		[string trim [lindex "$arg" 0] :]
			set destination	[lindex $arg 2]
			set cmd			[string trim [stripcodes * [lindex $arg 3]] :]
			set data		[lrange $arg 4 end]

			##########################
			#--> Commandes Privés <--#
			##########################
			# si $destination ne commence pas par # c'est un pseudo
			if { [string index $destination 0] != "#"} {
				if { $cmd == "join"		}	{ 
					# [22:50:42] Received: :001119S0G PRIVMSG 00CAAAAAB :join
					ClaraServ::IRC:CMD:PRIV:JOIN $sender $destination $cmd $data 
				}
				if { $cmd == "part"		}	{ 
					# [21:49:04] Received: :001119S0G PRIVMSG 00CAAAAAB :part
					ClaraServ::IRC:CMD:PRIV:PART $sender $destination $cmd $data 
				}
				if { $cmd == "help"		}	{ 
					# [21:49:04] Received: :001119S0G PRIVMSG 00CAAAAAB :part
					ClaraServ::IRC:CMD:PRIV:HELP $sender $destination $cmd $data 
				}
			}
			##########################
			#--> Commandes Salons <--#
			##########################
			# si $destination commence par # c'est un salon
			if { [string index $destination 0] == "#"} {
				if { $cmd == "!cmds"	}	{ 
					# [22:10:39] Received: :MalaGaM PRIVMSG #Eva :!cmds
					ClaraServ::IRC:CMD:PUB:CMDS $sender $destination $cmd $data 
				}
				if { $cmd == "!help"	}	{ 
					# Received: :MalaGaM PRIVMSG #Eva :!help
					ClaraServ::IRC:CMD:PUB:HELP $sender $destination $cmd $data 
				}
				if { $cmd == "!random"	}	{
					# [22:10:04] Received: :MalaGaM PRIVMSG #Eva :!random
					 ClaraServ::IRC:CMD:PUB:RANDOM $sender $destination $cmd $data
				}
				# Nous verifions si la commande corresponds a une commandes de la database:
				if { [lsearch -nocase [ClaraServ::FCT::DB:CMD:LIST] $cmd] != "-1" } {
					if { [catch {ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $cmd $data } error] } {
						ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "\[ERROR\] CMD: $cmd - Error: $error"
					}
				}
			}
		}
		"UID"		{
			set nickname		[lindex $arg 2]
			set uid				[string toupper [lindex $arg 7]]
			set UID_DB([string toupper $nickname])	$uid
			set UID_DB([string toupper $uid])		$nickname

		}
	}
}
#######################
#  --> Commandes <--  #
#######################
proc ClaraServ::IRC:CMD:PRIV:HELP { sender destination cmd data } {
	ClaraServ::IRC:CMD:PUB:HELP $sender $destination $cmd $data
}
proc ClaraServ::IRC:CMD:PUB:HELP { sender destination cmd data } {
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Aide publique<c04> :."
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> !help   - <c06>  Affiche cette aide"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> !cmds   - <c06>  Affiche la list des commandes"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> !random - <c06>  Affiche un text aleatoire"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Aide privé<c04> :."
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> help    - <c06>  Affiche cette aide"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> join    - <c06>  faire joindre un salon"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c07> part    - <c06>  faire quitter un salon"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	ClaraServ::FCT::CMD:LOG $cmd [ClaraServ::FCT::DATA:TO:NICK $sender]
}
proc ClaraServ::IRC:CMD:PUB:RANDOM { sender destination cmd data } {
	variable config
	set CMD_RANDOM	[lindex [ClaraServ::FCT::DB:CMD:LIST] [rand [llength [ClaraServ::FCT::DB:CMD:LIST]]]]
	if { [catch {ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $CMD_RANDOM $data } error] } {
			ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "\[ERROR\] CMD: $cmd - Error: $error"
	}
}
proc ClaraServ::IRC:CMD:PUB:DYNAMIC { sender destination cmd pseudo } {
	if { $pseudo == "" } {
		set data [ClaraServ::FCT::DB:GET $cmd 0];
	} else {
		set data [ClaraServ::FCT::DB:GET $cmd 1];
	}
	if { $data != "-1" } {
		set data	[ClaraServ::FCT::substitute_special_vars_2nd_pass $destination $data];
		set data	[string map -nocase [list "%pseudo%" "$pseudo" "%sender%" "$sender" "%destination%" "$destination"] $data]
		ClaraServ::FCT::SENT:PRIVMSG $destination $data
	}
	ClaraServ::FCT::CMD:LOG "!random" $sender
}

proc ClaraServ::IRC:CMD:PUB:CMDS { sender destination cmd data } {
	variable config
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Liste des commandes d'animation<c04> :."
	ClaraServ::FCT::CMD:SHOW:LIST $sender
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> .: <c12>Autre<c04> :."
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c12>!help    </c>-<c04> Affiche l'aide"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c12>!random  </c>-<c04> Affiche un text aleatoire"
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04> "
	ClaraServ::FCT::SENT:MSG:TO:USER $sender  "<c04>  * <b>Note:</b> Il y a certaine commandes qui ne sont pas activées sur tous les salons."
	ClaraServ::FCT::CMD:LOG $cmd $sender 
}
##########################################
# --> Procedures des Commandes Privés <--#
##########################################


proc ClaraServ::IRC:CMD:PRIV:JOIN { sender destination cmd data } {
	variable config
	# $sender $destination $cmd $data <------------------------
	# 001119S0G 00CAAAAAB join {#salon} lepassquetamisenconf <---------------
	# /msg clara join #salon lepassquetamisenconf
	set chan		[lindex $data 0]
	set password	[lindex $data 1]
	if { $password == "" } {
		ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Mauvaise syntaxe: /msg $config(service_nick) join #salon admin_password"
	} elseif { $password eq "$config(admin_password)" } {
		if { [ClaraServ::FCT::DB:SALON:ADD $chan] == 1} {
			ClaraServ::FCT::Socket:Sent ":$config(service_nick) JOIN $chan"
			ClaraServ::FCT::Socket:Sent ":$config(service_nick) MODE $chan +$config(service_usermodes) $config(service_nick)"

			ClaraServ::FCT::SENT:MSG:TO:USER $sender  "AddChan : $chan"
			if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Join :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender] "  }
		} else {
			ClaraServ::FCT::SENT:MSG:TO:USER $sender  "AddChan : $chan | Erreur Non ajouter "
			if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Join :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender] | Erreur Non ajouter " }
		}

	} else {
		ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Accés Refusè."
			if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Join :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender] </c>-><c04> Accés Refusè."  }
	}
}

proc ClaraServ::IRC:CMD:PRIV:PART { sender destination cmd data } {
	variable config
	# /msg clara part #salon lepassquetamisenconf
	set chan		[lindex $data 0]
	set password	[lindex $data 1]
	if { $password == "" } {
		ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Mauvaise syntaxe: /msg $config(service_nick) part #salon admin_password"
	} elseif { $password eq "$config(admin_password)" } {
		if { [string match -nocase $config(service_channel) $chan] } {
			ClaraServ::FCT::SENT:MSG:TO:USER $sender  "DelChan : $chan | Erreur: impossible $config(service_channel) est le salon de logs."
			if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender]  | Erreur: impossible $config(service_channel) est le salon de logs." }
		} elseif { [ClaraServ::FCT::DB:DATA:REMOVE "salon" $chan] == 1 } {
			ClaraServ::FCT::Socket:Sent ":$config(service_nick) PART $chan"
			ClaraServ::FCT::SENT:MSG:TO:USER $sender  "DelChan : $chan"
			if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender] "  }
		} else {
			ClaraServ::FCT::SENT:MSG:TO:USER $sender  "DelChan : $chan | Erreur Non ajouter "
			if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender] | Erreur Non suprimer " }
		}


	} else {
		ClaraServ::FCT::SENT:MSG:TO:USER $sender  "Accés Refusè."
		if {$config(admin_console) eq "1"} { ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "<c12>Part :<c04> $chan </c>par <c04>[ClaraServ::FCT::UID:CONVERT $sender] </c>-><c04> Accés Refusè."  }
	}
}

ClaraServ::INIT
