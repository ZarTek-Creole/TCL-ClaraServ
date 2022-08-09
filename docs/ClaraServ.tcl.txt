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
if {[info commands ::ClaraServ::uninstall] == "::ClaraServ::uninstall" } { ::ClaraServ::uninstall }
namespace eval ClaraServ {
	variable CONNECT_ID
	variable BOT_ID
	variable DIR
	variable SCRIPT
	variable config

	set DIR(CUR)			[file dirname [file dirname [file normalize [file join [info script] ...]]]]
	set CONNECT_ID			{}
	set BOT_ID				{}
	array set Script {
		"name"		"ClaraServ Service"
		"version"	"1.1.5"
		"auteur"	"ZarTek"
		"url"		"https://github.com/ZarTek-Creole/TCL-ClaraServ"
		"need_zct"	"0.0.9"
		"need_ircs"	"0.0.7"
	}
	set Script(dirname)	[file dirname [info script]]

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
		"log_command"		\
		"db_lang"
	];
	# Verification si le package ZCT a été mis dans le projet courant et si oui  le sourcé(charger)
	if { 
		[file exists ${DIR(CUR)}/modules/TCL-ZCT/ZCT.tcl] 					&& \
		[catch { source ${DIR(CUR)}/modules/TCL-ZCT/ZCT.tcl  } err] 
	} { 
		die "\[${::ClaraServ::Script(name)} - Erreur\] Chargement '${DIR(CUR)}/modules/TCL-ZCT/ZCT.tcl' à échoué: ${err}";
	}
	# Necesite le package ZCT, tentative de chargment de celui-ci
	if { [catch { package require ZCT ${::ClaraServ::Script(need_zct)} } err] } { die "\[${::ClaraServ::Script(name)} - Erreur\] Nécessite le package ZCT ${::ClaraServ::Script(need_zct)} (ou supérieur) pour fonctionner.\nLe chargement du script a été annulé.\nTélécharger-le sur 'https://github.com/ZarTek-Creole/TCL-ZCT'.\n${err}" ; }
	# Importation des fonctions de ZTC
	namespace import -force ::ZCT::*

	# Verification si le package ZCT a été mis dans le projet courant et si oui  le sourcé(charger)
	if {
		[file exists ${DIR(CUR)}/modules/TCL-PKG-IRCServices/ircservices.tcl] && \
			[catch { source ${DIR(CUR)}/modules/TCL-PKG-IRCServices/ircservices.tcl } err]
	} {
		die "\[${::ClaraServ::Script(name)} - Erreur\] Chargement '${DIR(CUR)}/modules/TCL-PKG-IRCServices/ircservices.tcl' à échoué: ${err}";
	}
	# Necesite le package ZCT, tentative de chargment de celui-ci via la fct de ZCT
	pkg load IRCServices ${::ClaraServ::Script(need_ircs)} ${::ClaraServ::Script(name)}

	namespace eval FCT {
		namespace import -force ::ZCT::*
	}

}
proc ::ClaraServ::uninstall {} {
	putlog "Désallocation des ressources de \002[set ::ClaraServ::Script(name)]\002..."

	foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?${ns}"] {
		unbind [lindex ${binding} 0] [lindex ${binding} 1] [lindex ${binding} 2] [lindex ${binding} 4]
	}
	namespace delete ::ClaraServ
}
proc ::ClaraServ::INIT { } {
	#################
	# ClaraServ Fichier #
	#################
	if { ![file isdirectory "[::ClaraServ::FCT::Get:ScriptDir "db"]"] } { file mkdir "[::ClaraServ::FCT::Get:ScriptDir "db"]" }

	################
	# ClaraServ Source #
	################
	if { [file exists [::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf] } {
		namespace inscope ::ClaraServ {
			if { [ catch { source [::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf } err ] } {
				putlog "\[ Erreur \] Probleme de chargement de '[::ClaraServ::FCT::Get:ScriptDir]ClaraServ.conf': ${err}"
				exit
			}
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

	set ::ClaraServ::config(FILE_DB)	"database.[string tolower ${::ClaraServ::config(db_lang)}].db"
	# generer les db si elle n'existe pas
	::ClaraServ::FCT::DB:INIT [list  {*}${::ClaraServ::config(db_list)} {*}${::ClaraServ::config(FILE_DB)}]

	if { [file exists [::ClaraServ::FCT::Get:ScriptDir "db"]/${::ClaraServ::config(FILE_DB)}] } {
		if { [ catch { source [::ClaraServ::FCT::Get:ScriptDir "db"]/${::ClaraServ::config(FILE_DB)} } err ] } {
			putlog "\[ Erreur \] Probleme de chargement de '[::ClaraServ::FCT::Get:ScriptDir "db"]/${::ClaraServ::config(FILE_DB)}': ${err}"
			exit
		}
	} else {
		putlog "Fichier de base de données '[::ClaraServ::FCT::Get:ScriptDir "db"]/${::ClaraServ::config(FILE_DB)}' manquant."
		exit
	}

	putlog "\[[set ::ClaraServ::Script(name)] - Chargement\]\003 v[set ::ClaraServ::Script(version)] par [set ::ClaraServ::Script(auteur)] charger."
}

#######################
# ClaraServ fonctions #
#######################
proc ::ClaraServ::FCT::Get:ScriptDir { {DIR ""} } {
	return "[file normalize ${::ClaraServ::Script(dirname)}/${DIR}]/"
}

proc ::ClaraServ::FCT::Check:Config { } {
	foreach CONF ${::ClaraServ::config(vars_list)} {
		if { ![info exists ::ClaraServ::config($CONF)] } {
			putlog "\[ Erreur \] Configuration de ClaraServ Service Incorrecte... '::ClaraServ::config($CONF)' Paramettre manquant"
			exitInformation
		}
		if { $::ClaraServ::config($CONF) == "" } {
			putlog "\[ Erreur \] Configuration de ClaraServ Service Incorrecte... '::ClaraServ::config($CONF)' Valeur vide"
			exit
		}
	}
}

proc ::ClaraServ::FCT::DB:GET { CMD NIVEAU } {
	foreach index [lsearch -all -nocase [::ZCT::TXT::remove_accents ${::ClaraServ::database}] "*${CMD}*"] {
		set index_data	[lindex ${::ClaraServ::database} ${index}]
		set type		[lindex ${index_data} 1]
		set data		[lindex ${index_data} 2]
		if { ${type} == ${NIVEAU} } {
			return [::ZCT::TXT::remove_accents ${data}]
		}
	}
	return -1
}
proc ::ClaraServ::FCT::DB:CMD:LIST { } {
	set ltext		[llength ${::ClaraServ::database}];
	set text		[lindex ${::ClaraServ::database} 0];
	set CMD_LIST	[list];
	set x			0;
	while { ${x} < ${ltext} } {
		lappend CMD_LIST [lindex [lindex ${::ClaraServ::database} ${x}] 0]
		lappend CMD_LIST [lindex [lindex ${::ClaraServ::database} ${x}] 1]
		incr x
	}
	return [lsort -unique ${CMD_LIST}]
}

proc ::ClaraServ::FCT::SENT:NOTICE { DEST MSG } {
	${::ClaraServ::BOT_ID}	notice ${DEST} [::ZCT::TXT::visuals::apply ${MSG}]
}

proc ::ClaraServ::FCT::SENT:PRIVMSG { DEST MSG } {
	${::ClaraServ::BOT_ID}	privmsg ${DEST} [::ZCT::TXT::visuals::apply ${MSG}]
}
proc ::ClaraServ::FCT::SENT:MSG:TO:USER { DEST MSG } {
	if { ${::ClaraServ::config(uplink_useprivmsg)} == 1 } {
		::ClaraServ::FCT::SENT:PRIVMSG ${DEST} ${MSG} ;
	} else {
		SNOTICE ${::ClaraServ::BOT_ID} ${DEST} ${MSG} ;
	}
}
proc ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG { MSG } {
	::ClaraServ::FCT::SENT:PRIVMSG ${::ClaraServ::config(service_channel)} ${MSG} ;
}

proc ::ClaraServ::FCT::DB:INIT { LISTDB } {
	foreach DB_FILE_NAME [split ${LISTDB}] {
		if { ![file exists "[::ClaraServ::FCT::Get:ScriptDir "db"]${DB_FILE_NAME}"] } {
			set FILE_PIPE	[open "[::ClaraServ::FCT::Get:ScriptDir "db"]${DB_FILE_NAME}" a+];
			close ${FILE_PIPE}
		}
	}
}
proc ::ClaraServ::FCT::CMD:LOG { cmd sender } {
	if {
		${::ClaraServ::config(log_command)}	== "1"						&& \
			${cmd} 								!= ""
	} {
		::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Commandes :<c04> %s <c12>par<c04> %s" ${cmd} ${sender}]
	}
}

proc ::ClaraServ::FCT::CMD:SHOW:LIST { DEST } {
	set max				8;
	set l_espace		13;
	set CMD_LIST		""
	foreach CMD [::ClaraServ::FCT::DB:CMD:LIST] {
		lappend CMD_LIST	"<c04>[::ZCT::TXT::visuals::espace ${CMD} ${l_espace}]<c12>"
		if { [incr i] > ${max}-1 } {
			unset i
			::ClaraServ::FCT::SENT:MSG:TO:USER ${DEST} [join ${CMD_LIST} " | "];
			set CMD_LIST	""
		}
	}
	::ClaraServ::FCT::SENT:MSG:TO:USER ${DEST} [join ${CMD_LIST} " | "];
	::ClaraServ::FCT::SENT:MSG:TO:USER ${DEST} "<c>";
}

proc ::ClaraServ::FCT::DB:DATA:EXIST { DB DATA } {
	set DB_FILE			"[::ClaraServ::FCT::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist ${DB_FILE}] } { return "-1"; }
	set FILE_PIPE		[open ${DB_FILE} r];
	while { ![eof ${FILE_PIPE}] } {
		gets ${FILE_PIPE} FILE_DATA;
		if { [string match -nocase ${DATA} ${FILE_DATA}] } {
			close ${FILE_PIPE};
			return 1;
		}
	}
	close ${FILE_PIPE};
	return 0;
}

proc ::ClaraServ::FCT::DB:SALON:ADD { SALON } {
	if { [string index ${SALON} 0] != "#" } { return 0; }
	if { [::ClaraServ::FCT::DB:DATA:EXIST "salon" ${SALON}] == 0 } {
		set DB_FILE			"[::ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
		set FILE_PIPE		[open ${DB_FILE} a];
		puts ${FILE_PIPE} 	${SALON};
		close ${FILE_PIPE};
		return 1;
	} else {
		return -1;
	}
}

proc ::ClaraServ::FCT::DB:DATA:REMOVE { DB DATA } {
	set DB_FILE			"[::ClaraServ::FCT::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist ${DB_FILE}] } { return "-1"; }
	set FILE_PIPE		[open ${DB_FILE} r];
	set STATE			0;
	set FILE_NEW_DATA	[list];
	while { ![eof ${FILE_PIPE}] } {
		gets ${FILE_PIPE} FILE_DATA;
		if { [string match -nocase ${DATA} ${FILE_DATA}] } {
			set STATE		1;
		} elseif { ${FILE_DATA} != "" } {
			lappend FILE_NEW_DATA ${FILE_DATA};
		}
	}
	close ${FILE_PIPE}
	set FILE_PIPE		[open ${DB_FILE} w+];
	foreach LINE_NEW ${FILE_NEW_DATA} { puts ${FILE_PIPE} ${LINE_NEW} }
	close ${FILE_PIPE}
	return ${STATE};
}
####################
#--> Procedures <--#
####################
proc ::ClaraServ::FCT::Create:Services {} {
	if { ${::ClaraServ::config(uplink_ssl)} == 1		} { set ::ClaraServ::config(uplink_port) "+${::ClaraServ::config(uplink_port)}" }
	if { ${::ClaraServ::config(serverinfo_id)} != ""	} { set ::ClaraServ::config(uplink_ts6) 1 } else { set ::ClaraServ::config(uplink_ts6) 0 }

	set ::ClaraServ::CONNECT_ID [::IRCServices::connection]; # Creer une instance services
	${::ClaraServ::CONNECT_ID} connect ${::ClaraServ::config(uplink_host)} ${::ClaraServ::config(uplink_port)} ${::ClaraServ::config(uplink_password)} ${::ClaraServ::config(uplink_ts6)} ${::ClaraServ::config(serverinfo_name)} ${::ClaraServ::config(serverinfo_id)}; # Connexion de l'instance service
	if { ${::ClaraServ::config(uplink_debug)} == 1 } { ${::ClaraServ::CONNECT_ID} config logger 1; ${::ClaraServ::CONNECT_ID} config debug 1; }

	set ::ClaraServ::BOT_ID [${::ClaraServ::CONNECT_ID} bot]; #Creer une instance bot dans linstance services

	${::ClaraServ::BOT_ID} create ${::ClaraServ::config(service_nick)} ${::ClaraServ::config(service_user)} ${::ClaraServ::config(service_host)} ${::ClaraServ::config(service_gecos)} ${::ClaraServ::config(service_modes)}; # Creation d'un bot service
	${::ClaraServ::BOT_ID} join ${::ClaraServ::config(service_channel)}
	${::ClaraServ::BOT_ID} registerevent EOS {
		[sid] mode ${::ClaraServ::config(service_channel)} ${::ClaraServ::config(service_chanmodes)}
		if { ${::ClaraServ::config(service_usermodes)} != "" } {
			[sid] mode ${::ClaraServ::config(service_channel)} ${::ClaraServ::config(service_usermodes)} ${::ClaraServ::config(service_nick)}
		}
		set DB(Channels) "[::ClaraServ::FCT::Get:ScriptDir "db"]/salon.db"
		set FILE_PIPE	[open ${DB(Channels)} "r"]
		while {![eof ${FILE_PIPE}]} {
			set data	[gets ${FILE_PIPE}]
			if { ${data} != "" } {
				[bid] join ${data}
				if { ${::ClaraServ::config(service_usermodes)} != "" } {
					[sid] mode ${data} ${::ClaraServ::config(service_usermodes)} ${::ClaraServ::config(service_nick)}
				}
			}
			unset data
		}
		close ${FILE_PIPE}

	}
	${::ClaraServ::BOT_ID} registerevent PRIVMSG {
		set IRC_CMD		[::ZCT::TXT::remove_accents [lindex [msg] 0]]
		set IRC_VALUE	[lrange [msg] 1 end]

		##########################
		#--> Commandes Privés <--#
		##########################
		# si [target] ne commence pas par # c'est un pseudo (commande privée)
		if { [string index [target] 0] != "#"} {
			# Si la commande existe pas, on dit a l'utilisateur qu'elle est inconnue
			if { [info procs ::ClaraServ::IRC:CMD:PRIV:[string toupper ${IRC_CMD}]] == "" } {
				::ClaraServ::FCT::SENT:MSG:TO:USER [who2] [format "Commande %s inconnue" ${IRC_CMD}]
				::ClaraServ::IRC:CMD:PRIV:HELP [who2] ${IRC_VALUE}
				return 0;
			}
			# au sinon, on l'execute
			if { [catch { set OK [::ClaraServ::IRC:CMD:PRIV:[string toupper ${IRC_CMD}] [who2] [target] ${IRC_CMD} ${IRC_VALUE}] } EXEC_ERROR] } {
				#Si il y a une erreur on l'affiche sur le chan log
				foreach line [split ${::errorInfo} "\n"] {
					::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG ${line}
					putlog ${line} error IRC:CMD:MSG:PRIV
				}
				return 0;
			} else {
				# si elle reusi on retourne le status
				return ${OK};
			}
		}
		##########################
		#--> Commandes Salons <--#
		##########################
		# si [target] commence par # c'est un salon (commande publique)
		if { [string index [target] 0] == "#"} {

			# Ont verifie si la commande existe
			if { [info procs ::ClaraServ::IRC:CMD:PUB:[string toupper [string range ${IRC_CMD} 1 end]]] != "" } {
				# si elle existe ont l'execute
				if { [catch { set OK [::ClaraServ::IRC:CMD:PUB:[string toupper [string range ${IRC_CMD} 1 end]] [who] [target] ${IRC_CMD} ${IRC_VALUE}] } EXEC_ERROR] } {
					#Si il y a une erreur on l'affiche sur le chan log
					foreach line [split ${::errorInfo} "\n"] {
						::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG ${line}
						putlog ${line} error IRC:CMD:MSG:PRIV
					}
					return 0;
				}
			}
			# Si la commande existe pas en tant que PROC, alors nous verifions si la commande corresponds a une commandes de la database:
			if { [lsearch -nocase [::ZCT::TXT::remove_accents [::ClaraServ::FCT::DB:CMD:LIST]] ${IRC_CMD}] != "-1" } {
				#Si la database trouve une corespondance ont execute :
				if { [catch {::ClaraServ::IRC:CMD:PUB:DYNAMIC [who] [target] ${IRC_CMD} ${IRC_VALUE} } error] } {
					foreach line [split ${::errorInfo} "\n"] {
						::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG ${line}
						putlog ${line} error IRC:CMD:MSG:PRIV
					}
				}
			}
		}
	}
	# Creer un event sur PRIVMSG fin
}
#######################
#  --> Commandes <--  #
#######################


proc ::ClaraServ::IRC:CMD:PUB:RANDOM { sender destination cmd data } {
	# /msg #chan !random [nick]
	set CMD_RANDOM	[lindex [::ClaraServ::FCT::DB:CMD:LIST] [rand [llength [::ClaraServ::FCT::DB:CMD:LIST]]]]
	if { [catch {ClaraServ::IRC:CMD:PUB:DYNAMIC ${sender} ${destination} ${CMD_RANDOM} ${data} } error] } {
		::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG "\[ERROR2\] CMD: ${CMD_RANDOM} - Error: ${error}"
	}
}
proc ::ClaraServ::IRC:CMD:PUB:DYNAMIC { sender destination cmd pseudo } {
	if { ${pseudo} == "" } {
		set data [::ClaraServ::FCT::DB:GET ${cmd} 0];
	} else {
		set data [::ClaraServ::FCT::DB:GET ${cmd} 1];
	}
	if { ${data} != "-1" } {
		set data	[::ZCT::TXT::REPLACE_SUBSTITUTE ${data} ${destination}];
		set data	[string map -nocase [list "%pseudo%" "${pseudo}" "%sender%" "${sender}" "%destination%" "${destination}"] ${data}]
		::ClaraServ::FCT::SENT:PRIVMSG ${destination} ${data}
	}
	::ClaraServ::FCT::CMD:LOG ${cmd} ${sender}
}
proc ::ClaraServ::IRC:CMD:PUB:CMDS { sender destination cmd data } {
	#  /msg ClaraServ !cmds
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${destination} [format "<c04> .: <c12>Liste des commandes envoyée en privé à %s<c04> :." ${sender}]
	::ClaraServ::IRC:CMD:PRIV:CMDS ${sender} ${destination} ${cmd} ${data}
}
proc ::ClaraServ::IRC:CMD:PRIV:CMDS { sender destination cmd data } {
	#  /msg ClaraServ cmds
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} "<c04> .: <c12>Liste des commandes d'animations<c04> :."
	::ClaraServ::FCT::CMD:SHOW:LIST 	${sender}
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} "<c04> .: <c12>Autres<c04> :."
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} "<c12>!help    </c>-<c04> Affiche l'aide"
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} "<c12>!random  </c>-<c04> Affiche un text aleatoire"
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} [format "<c12>!about  </c>-<c04> Affiche des informations sur %s" ${::ClaraServ::config(service_nick)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} "<c04> "
	::ClaraServ::FCT::CMD:LOG ${cmd} ${sender}
}

proc ::ClaraServ::IRC:CMD:PUB:ABOUT { sender destination cmd data } {
	#  /msg ClaraServ !about
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${destination} [format "<c04> .: <c12>Information de %s envoyée en privé à %s<c04> :." ${::ClaraServ::config(service_nick)} ${sender}]
	::ClaraServ::IRC:CMD:PRIV:ABOUT ${sender} ${destination} ${cmd} ${data}
}
proc ::ClaraServ::IRC:CMD:PRIV:ABOUT { sender destination cmd data } {
	#  /msg ClaraServ about
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} [format "<c04> .: <c12>A propos de %s<c04> :." ${::ClaraServ::Script(name)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} [format "<c07>Version     <c12>:<c06> v%s" ${::ClaraServ::Script(version)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} [format "<c07>Auteur      <c12>:<c06> %s" ${::ClaraServ::Script(auteur)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} [format "<c07>WebSite     <c12>:<c06> %s" ${::ClaraServ::Script(url)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER 	${sender} [format "<c07>Dépendances <c12>:<c07> ZCT v<c06>%s<c12>,<c07> IRCS v<c06>%s" ${::ClaraServ::Script(need_zct)} ${::ClaraServ::Script(need_ircs)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> "
	::ClaraServ::FCT::CMD:LOG ${cmd} ${sender}
}
##########################################
# --> Procedures des Commandes Privés <--#
##########################################
proc ::ClaraServ::IRC:CMD:PUB:HELP { sender destination cmd data } {
	# /msg #chan !help
	::ClaraServ::FCT::SENT:MSG:TO:USER	${destination} [format "<c04> .: <c12>Aide envoyée en privé à %s<c04> :." ${sender}]
	::ClaraServ::IRC:CMD:PRIV:HELP ${sender} ${destination} ${cmd} ${data}
}
proc ::ClaraServ::IRC:CMD:PRIV:HELP { sender destination cmd data } {
	# /msg ClaraServ help
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> .: <c12>Aide pour les commandes en salon<c04> :."
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c07> !help                                <c07>-<c06>   Affiche cette aide"
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c07> !cmds                                <c07>-<c06>   Affiche la list des commandes"
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c07> !random                              <c07>-<c06>   Affiche un text aleatoire"
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "<c07> !about                               <c07>-<c06>   A propos de %s" ${::ClaraServ::config(service_nick)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> .: <c12>Aide pour les commandes en privé<c04> :."
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> "
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c07> help                                 <c07>-<c06>   Affiche cette aide"
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c07> cmds                                 <c07>-<c06>   Affiche la list des commandes"
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "<c07> about                                <c07>-<c06>   A propos de %s" ${::ClaraServ::config(service_nick)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "<c07> join <s><<c06>#Salon<s>> <<c06>Mot_de_passe_admin<s>>   <c07>-<c06>   Joindre le robot %s sur le <s><<c06>#Salon<s>>" ${::ClaraServ::config(service_nick)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "<c07> part <s><<c06>#Salon<s>> <<c06>Mot_de_passe_admin<s>>   <c07>-<c06>   Retiré le robot %s du <s><<c06>#Salon<s>>" ${::ClaraServ::config(service_nick)}]
	::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "<c04> "
	::ClaraServ::FCT::CMD:LOG ${cmd} ${sender}
}

proc ::ClaraServ::IRC:CMD:PRIV:JOIN { sender destination cmd data } {
	#  /msg ClaraServ join <#Salon> <Mot_de_passe_admin>
	set chan		[lindex ${data} 0]
	set password	[lindex ${data} 1]

	if { ${password} == "" } {
		::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "<c12>Mauvaise syntaxe<s>:<c07> /msg <c14>%s<c07> %s <s><<c06>#Salon<s>> <<c06>Mot_de_passe_admin<s>>" ${::ClaraServ::config(service_nick)} "join"]
	} elseif { ${password} == "${::ClaraServ::config(admin_password)}" } {
		if { [::ClaraServ::FCT::DB:SALON:ADD ${chan}] == 1 } {
			${::ClaraServ::BOT_ID} join ${chan}
			${::ClaraServ::BOT_ID} mode ${chan} +${::ClaraServ::config(service_usermodes)} ${::ClaraServ::config(service_nick)}
			::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "Le robot a rejoin %s" ${chan}]
			if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Join :<c04> %s </c>par <c04>%s" ${chan} ${sender}] }
		} else {
			::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "Le robot n'a pas su joindre %s" ${chan}]
			if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Join :<c04> %s </c>par <c04>%s | Erreur Non ajouter " ${chan} ]${sender} }
		}
	} else {
		::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "Accés Refusè."
		if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Join :<c04> %s </c>par <c04>%s </c>-><c04> Accés Refusè." ${chan} ${sender}]  }
	}
}

proc ::ClaraServ::IRC:CMD:PRIV:PART { sender destination cmd data } {
	#  /msg ClaraServ part <#Salon> <Mot_de_passe_admin>
	set chan		[lindex ${data} 0]
	set password	[lindex ${data} 1]

	if { ${password} == "" } {
		::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} [format "<c12>Mauvaise syntaxe<s>:<c07> /msg <c14>%s<c07> %s <s><<c06>#Salon<s>> <<c06>Mot_de_passe_admin<s>>" ${::ClaraServ::config(service_nick)} "part"]
	} elseif { ${password} == "${::ClaraServ::config(admin_password)}" } {
		if { [string match -nocase ${::ClaraServ::config(service_channel)} ${chan}] } {
			::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "DelChan : ${chan} | Erreur: impossible ${::ClaraServ::config(service_channel)} est le salon de logs."
			if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG  [format "<c12>Part :<c04> %s </c>par <c04>%s | Erreur: impossible %s est le salon de logs." ${chan} ${sender} ${::ClaraServ::config(service_channel)}] }
		} elseif { [::ClaraServ::FCT::DB:DATA:REMOVE "salon" ${chan}] == 1 } {
			${::ClaraServ::BOT_ID} part ${chan}
			::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "DelChan : ${chan}"
			if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Part :<c04> %s </c>par <c04>%s" ${chan} ${sender}] }
		} else {
			::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "DelChan : ${chan} | Erreur Non ajouter "
			if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Part :<c04> %s </c>par <c04>%s | Erreur Non suprimer " ${chan} ${sender}] }
		}
	} else {
		::ClaraServ::FCT::SENT:MSG:TO:USER ${sender} "Accés Refusè."
		if { ${::ClaraServ::config(log_command)} == 1 } { ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG [format "<c12>Part :<c04> %s </c>par <c04>%s </c>-><c04> Accés Refusè." ${chan} ${sender}] }
	}
}

::ClaraServ::INIT
::ClaraServ::FCT::Create:Services
