# irc.tcl --
#
#	irc services implementation for Tcl.
# based from irc package by tcllib
#
# -------------------------------------------------------------------------
namespace eval ::IRCServices {
	variable PKG
	variable DIR
	set DIR(CUR)			[file dirname [file dirname [file normalize [file join [info script] ...]]]]
	array set PKG {
		"version"			"0.0.7"
		"need_tcl"			"8.6"
		"need_tls"			"1.7.16"
		"need_logger"		"0.9.4"
		"need_zct"			"0.0.4"
		"name"				"package IRCServices"
	}
	variable conn			0
	variable botn 			0
	variable config
	variable irctclfile 	[info script]
	variable newCharArray	[list]
	array set config 		{
		debug  0
		logger 0
	}
	if { [file exists ${DIR(CUR)}/TCL-ZCT/ZCT.tcl] } { catch { source ${DIR(CUR)}/TCL-ZCT/ZCT.tcl } }
	if { [catch { package require ZCT ${PKG(need_zct)} } err] } {
		die "\[${PKG(name)} - erreur\] Nécessite le package ZCT ${PKG(need_zct)} (ou plus) pour fonctionner, Télécharger sur 'https://github.com/ZarTek-Creole/TCL-ZCT'.\nLe chargement du script a été annulé." ;
	} else { namespace import -force ::ZCT::* }
	pkg load Tcl ${PKG(need_tcl)} ${PKG(name)}
	pkg load logger ${PKG(need_logger)} ${PKG(name)}
}	

proc ::IRCServices::config { args } {
	variable config
	if { [llength ${args}] == 0 } {
		return [array get config]
	} elseif { [llength ${args}] == 1 } {
		set key [lindex ${args} 0]
		return $config(${key})
	} elseif { [llength ${args}] > 2 } {
		error "wrong # args: should be \"config key ?val?\""
	}
	# llength ${args} == 2
	set key		[lindex ${args} 0]
	set value	[lindex ${args} 1]
	foreach ns [namespace children] {
		if {
			[info exists config(${key})]									&& \
			[info exists ${ns}::config(${key})] 							&& \
			[set ${ns}::config(${key})] == $config(${key})
		} {
				${ns}::cmd-config ${key} ${value}
		}
	}
	set config(${key}) ${value}
}

# ::IRCServices::connections --
#
# Return a list of handles to all existing connections
# Renvoie une liste de descripteurs de toutes les connexions existantes

proc ::IRCServices::connections { } {
	set r {}
	foreach ns [namespace children] {
		lappend r ${ns}::network
	}
	return ${r}
}

# ::IRCServices::reload --
#
# Reload this file, and merge the current connections into
# the new one.

proc ::IRCServices::reload { } {
	variable conn
	set oldconn ${conn}
	namespace eval :: {
		source [set ::IRCServices::IRCServicestclfile]
	}
	foreach ns [namespace children] {
		foreach var {sock logger host port} {
			set ${var} [set ${ns}::${var}]
		}
		array set dispatch	[array get ${ns}::dispatch]
		array set config	[array get ${ns}::config]
		# make sure our new connection uses the same namespace
		set conn	[string range ${ns} 10 end]
		::IRCServices::connection
		foreach var {sock logger host port} {
			set ${ns}::${var} [set ${var}]
		}
		array set ${ns}::dispatch [array get dispatch]
		array set ${ns}::config [array get config]
	}
	set conn ${oldconn}
}

# ::IRCServices::connection --
#
# Create an IRC connection namespace and associated commands.

proc ::IRCServices::connection { args } {
	variable conn
	variable config
	variable sid ""


	# Create a unique namespace of the form irc${conn}::${host}

	set name [format "%s::IRCServices%s" [namespace current] ${conn}]

	namespace eval ${name} {
		variable sock
		variable dispatch
		variable linedata
		variable config
		variable UID_DB
		variable [namespace current]::UID_LAST_INSERT
		variable botn 0
		variable sid ""

		set sock			{}
		array set dispatch	{}
		array set linedata	{}
		set UID_LAST_INSERT	{}
		array set config	[array get ::IRCServices::config]
		if { 
			${config(logger)}												|| \
			${config(debug)}
		} {
			variable logger
			set logger [logger::init [namespace tail [namespace current]]]
			if { !${config(debug)} } { ${logger}::disable debug }
		}
		proc TLSSocketCallBack { level args } {
			set SOCKET_NAME	[lindex ${args} 0]
			set type		[lindex ${args} 1]
			set socketid	[lindex ${args} 2]
			set what		[lrange ${args} 3 end]
			cmd-log debug "Socket '${SOCKET_NAME}' callback ${type}: ${what}"
			if { [string match -nocase "*certificate*verify*failed*" ${what}] } {
				cmd-log error "IRCServices Socket erreur: Vous essayez de vous connecter a un serveur TLS auto-signé. (${what}) [tls::status ${socketid}]"
			}
			if { [string match -nocase "*wrong*version*number*" ${what}] } {
				cmd-log error "IRCServices Socket erreur: Vous essayez sans doute de connecter en SSL sur un port Non-SSL. (${what})"
			}
		}

		# send --
		# send text to the IRC server

		proc send { msg } {
			variable sock
			variable dispatch
			if { ${sock}  eq "" } { return }
			cmd-log debug "send: '${msg}'"
			if { [catch {puts ${sock}  ${msg}} err] } {
				catch { close ${sock}  }
				set sock {}
				if { [info exists dispatch(EOF)] } {
					eval ${dispatch(EOF)}
				}
				cmd-log error "Error in send: ${err}"
			}
		}

		proc UID_GET { user } {
			variable config
			variable [namespace current]::UID_DB
			variable [namespace current]::UID_LAST_INSERT
			variable sid
			if { [UID_EXIST ${user}] } {
				return "$UID_DB([string toupper ${user}])"
			} else {
				if { ${UID_LAST_INSERT} == "" } {
					set UID_LAST_INSERT		"${sid}AAAAAA"
					return ${UID_LAST_INSERT}
				}
				set UID_NOW							[::IRCServices::incrementChar ${UID_LAST_INSERT}]
				set UID_LAST_INSERT					${UID_NOW}
				set UID_DB([string toupper ${user}])	${UID_NOW}
				return ${UID_NOW}
			}
		}
		proc UID_CONVERT { ID } {
			variable [namespace current]::UID_DB
			if { [info exists UID_DB([string toupper ${ID}])] } {
				return "$UID_DB([string toupper ${ID}])"
			} else {
				return ${ID}
			}
		}
		proc UID_EXIST { CIBLE } {
			variable config
			variable [namespace current]::UID_DB
			if { [info exists UID_DB([string toupper ${CIBLE}])]} {
				return 1
			} else {
				return 0
			}
		}

		#########################################################
		# Implemented user-side commands, meaning that these commands
		# cause the calling user to perform the given action.
		#########################################################


		# cmd-config --
		#
		# Set or return per-connection configuration options.
		#
		# Arguments:
		#
		# key	name of the configuration option to change.
		#
		# value	value (optional) of the configuration option.

		proc cmd-config { args } {
			variable config
			variable logger

			if { [llength ${args}] == 0 } {
				return [array get config]
			} elseif { [llength ${args}] == 1 } {
				set key [lindex ${args} 0]
				return $config(${key})
			} elseif { [llength ${args}] > 2 } {
				error "wrong # args: should be \"config key ?val?\""
			}
			set key		[lindex ${args} 0]
			set value	[lindex ${args} 1]
			if { ${key} eq "debug" } {
				if {${value}} {
					if { !${config(logger)} } { cmd-config logger 1 }
					${logger}::enable debug
				} elseif { [info exists logger] } {
					${logger}::disable debug
				}
			}
			if { ${key} eq "logger" } {
				if {
					${value}												&& \
					!${config(logger)}
				} {
					set logger [logger::init [namespace tail [namespace current]]]
				} elseif { [info exists logger] } {
					${logger}::delete
					unset logger
				}
			}
			set config(${key}) ${value}
		}

		proc cmd-log {level text} {
			variable logger
			if { ![info exists logger] } return
			${logger}::${level} ${text}
		}

		proc cmd-logname { } {
			variable logger
			if { ![info exists logger] } return
			return ${logger}
		}


		# cmd-destroy --
		#
		# destroys the current connection and its namespace

		proc cmd-destroy { } {
			variable logger
			variable sock
			if { [info exists logger] } { ${logger}::delete }
			catch { close ${sock} }
			namespace delete [namespace current]
		}

		proc cmd-connected { } {
			variable sock
			if { ${sock} eq "" } { return 0 }
			return 1
		}

		proc cmd-user { username hostname servername {userinfo ""} } {
			if { ${userinfo} eq "" } {
				send "USER ${username} ${hostname} server :${servername}"
			} else {
				send "USER ${username} ${hostname} ${servername} :${userinfo}"
			}
		}


		proc cmd-ping { target } {
			send "PRIVMSG ${target} :\001PING [clock seconds]\001"
		}

		proc cmd-serverping { } {
			send "PING [clock seconds]"
		}

		proc cmd-ctcp { target line } {
			send "PRIVMSG ${target} :\001${line}\001"
		}

		proc cmd-quit { {msg {tcl irc services module - github.com/ZarTek-Creole/TCL-PKG-IRCServices}} } {
			send "QUIT :${msg}"
		}

		proc cmd-notice { target msg } {
			send "NOTICE ${target} :${msg}"
		}

		proc cmd-kick { chan target {msg {}} } {
			send "KICK ${chan} ${target} :${msg}"
		}

		proc cmd-mode { DEST {MODE ""} {CIBLE ""} } {
			variable sid
			send ":${sid} MODE ${DEST} ${MODE} ${CIBLE}"
		}

		proc cmd-topic { chan msg } {
			send "TOPIC ${chan} :${msg}"
		}

		proc cmd-vusercreate { usernick username {userhost {localhost}} {usergecos {Package TCL IRCServices}} {usermodes {+qioS}} } {
			variable sid
			if { [UID_EXIST ${usernick}] } {
				set usernick ${usernick}_2
				set username ${username}2
			}
			set VU_UID		[UID_GET ${usernick}]
			send ":${sid} UID ${usernick} 1 [clock seconds] ${username} ${userhost} ${VU_UID} * ${usermodes} * * * :${usergecos}"
			return ${VU_UID}
		}

		proc cmd-invite { chan target } {
			send "INVITE ${target} ${chan}"
		}

		proc cmd-send { line } {
			send ${line}
		}

		proc cmd-peername { } {
			variable sock
			if { ${sock} eq "" } { return {} }
			return [fconfigure ${sock} -peername]
		}

		proc cmd-sockname { } {
			variable sock
			if { ${sock} eq "" } { return {} }
			return [fconfigure ${sock} -sockname]
		}

		proc cmd-socket { } {
			variable sock
			return ${sock}
		}


		proc cmd-disconnect { } {
			variable sock
			if { ${sock} eq "" } { return -1 }
			catch { close ${sock} }
			set sock {}
			return 0
		}

		# Connect --
		# Create the actual tcp connection.

		proc cmd-connect { hostname port password {ts6 1} {name eva.info} {id 00R}} {
			variable sock
			variable host
			variable s_port
			variable pass
			variable sname
			variable sid
			variable ::IRCServices::PKG

			set host	${hostname}
			set s_port	${port}
			set pass	${password}
			set sname	${name}
			set sid		${id}

			if { [string range ${s_port} 0 0] == "+" } {
				set secure	1;
				set port	[string range ${s_port} 1 end]
			} else {
				set secure	0;
				set port	${s_port}
			}
			if { ${secure} == 1 } {
				if { [catch { package require tls ${PKG(need_tls)} }] } {
					die "\[${PKG(name)} - Erreur\] Nécessite le package tls ${PKG(need_tls)} (ou plus) pour fonctionner, Télécharger sur 'https://core.tcl-lang.org/tcltls/index'. Le chargement du package a été annulé." ;
				}
				set socket_binary "::tls::socket -require 0 -request 0 -command \"[namespace current]::TLSSocketCallBack ${sock}\""
			} else {
				set socket_binary ::socket
			}
			if { ${sock} eq "" } {
				if { [catch {
					set sock [{*}${socket_binary} ${host} ${port}]
					} err] } { die "\[${PKG(name)} - Erreur\] Impossible de ce connecter sur ${host}:${port}: ${err}" }
					fconfigure ${sock}  -translation crlf -buffering line
					fileevent ${sock} readable [namespace current]::GetEvent
					if { ${ts6} } {
						send "PASS :${pass}"
						send "PROTOCTL NICKv2 VHP UMODE2 NICKIP SJOIN SJOIN2 SJ3 NOQUIT TKLEXT MLOCK SID"
						send "PROTOCTL EAUTH=${sname},,,IRCService-${PKG(version)}"
						send "PROTOCTL SID=${sid}"
						send ":${sid} SERVER ${sname} 1 :Services for IRC Networks"
						send "EOS"
					} else {
						send "PASS ${pass}"
						send "SERVER ${sname} 1 :Services for IRC Networks"
						send "EOS"
						#	send ":${sname} NICK $config(service_nick) 1 [clock seconds] $config(service_user) $config(service_host) ${sname} :$config(service_gecos)"
					}
				}
				return 1
			}

			proc cmd-bot { args } {
				variable botn
				variable config
				variable [namespace current]::UID_DB
				variable sid
				# Create a unique namespace of the form irc${botn}::${host}
				# ::IRCServices::IRCServices0::IRCServices0::bot

				set name [format "%s::b%s" [namespace current] ${botn}]

				namespace eval ${name} {
					variable sock
					variable dispatch
					variable linedata
					variable config
					variable [namespace parent]::sid
					set sock			{}
					array set dispatch	{}
					array set linedata	{}
					set UID_LAST_INSERT	{}
					array set config	[array get ::IRCServices::config]

					proc cmd-create { botnick botident bothost {botgecos {Package TCL IRCServices}} {botmodes {+qioS}} } {
						# ${bn1} connect ClaraServ identserv MyHost.be; # Creation d'un bot service ClaraServ
						variable bnick
						variable ident
						variable host
						variable config
						variable sid
						variable bid


						set bnick	${botnick}
						set ident	${botident}
						set host	${bothost}
						set bid		[[namespace parent]::UID_GET ${bnick}]
						set sid		[set [namespace parent]::sid]
						[namespace parent]::send ":${sid} SQLINE ${bnick} :Reserved for services"
						[namespace parent]::send ":${sid} UID ${bnick} 1 [clock seconds] ${ident} ${host} ${bid} * ${botmodes} * * * :${botgecos}"
						return 0
					}
					proc cmd-privmsg { target msg } {
						variable bid
						[namespace parent]::send ":${bid} PRIVMSG ${target} :${msg}"
					}
					proc cmd-notice { target msg } {
						variable bid
						[namespace parent]::send ":${bid} NOTICE ${target} :${msg}"
					}
					proc cmd-join { chan } {
						variable sid
						variable bid
						[namespace parent]::send ":${sid} SJOIN [clock seconds] ${chan} + :${bid}"
					}
					proc cmd-part { chan {msg ""} } {
						variable bid
						if { ${msg} eq "" } {
							[namespace parent]::send ":${bid} PART ${chan}"
						} else {
							[namespace parent]::send ":${bid} PART ${chan} :${msg}"
						}
					}
					proc cmd-mode { DEST {MODE ""} {CIBLE ""} } {
						variable bid
						[namespace parent]::send ":${bid} MODE ${DEST} ${MODE} ${CIBLE}"
					}
					proc cmd-send { line } {
						[namespace parent]::send ${line}
					}
					proc cmd-mesend { line } {
						variable bid
						[namespace parent]::send ":${bid} ${line}"
					}
					# registerevent --

					# Register an event in the dispatch table.

					# Arguments:
					# evnt: name of event as sent by IRC server.
					# cmd: proc to register as the event handler

					proc cmd-registerevent { evnt cmd } {
						variable dispatch
						set dispatch(${evnt}) ${cmd}
						if { ${cmd} eq "" } {
							unset dispatch(${evnt})
						}
					}

					# getevent --

					# Return the currently registered handler for the event.

					# Arguments:
					# evnt: name of event as sent by IRC server.

					proc cmd-getevent { evnt } {
						variable dispatch
						if { [info exists dispatch(${evnt})] } {
							return $dispatch($evnt)
						}
						return {}
					}

					# eventexists --

					# Return a boolean value indicating i[listf there is a handler
					# registered for the event.

					# Arguments:
					# evnt: name of event as sent by IRC server.

					proc cmd-eventexists { evnt } {
						variable dispatch
						return [info exists dispatch(${evnt})]
					}
					proc bot { cmd args } {
						if { [info proc [namespace current]::cmd-${cmd}] == "" } {
							return "sub-cmd inconnu. List: [join [string map [list "[namespace current]::cmd-" ""] [info proc [namespace current]::cmd-*]] ", "]"
						} else {
							eval [linsert ${args} 0 [namespace current]::cmd-${cmd}]
						}
					}

					# Create default handlers.

					set dispatch(PING)				{network send "PONG :[msg]"}
					set dispatch(defaultevent)		#
					set dispatch(defaultcmd)		#
					set dispatch(defaultnumeric)	#
				}


				set returncommand [format "%s::b%s::bot" [namespace current] ${botn}]
				incr botn
				return ${returncommand}
			}

			# Callback API:

			# These are all available from within callbacks, so as to
			# provide an interface to provide some information on what is
			# coming out of the server.

			# action --

			# Action returns the action performed, such as KICK, PRIVMSG,
			# MODE etc, including numeric actions such as 001, 252, 353,
			# and so forth.

			proc action { } {
				variable linedata
				return ${linedata(action)}
			}

			# msg --

			# The last argument of the line, after the last ':'.

			proc msg { } {
				variable linedata
				return ${linedata(msg)}
			}

			# who --

			# Who performed the action.  If the command is called as [who address],
			# it returns the information in the form
			# nick!ident@host.domain.net

			proc who { {address 0} } {
				variable linedata
				if { ${address} == 0 } {
					return [lindex [split ${linedata(who)} !] 0]
				} else {
					return ${linedata(who)}
				}
			}
			proc who2 { {address 0} } {
				variable linedata
				if { ${address} == 0 } {
					return [lindex [split ${linedata(who2)} !] 0]
				} else {
					return ${linedata(who2)}
				}
			}
			proc sid { } {
				variable linedata
				return ${linedata(sid)}
			}
			proc bid { } {
				variable linedata
				return ${linedata(bid)}
			}
			# target --

			# To whom was this action done.

			proc target { } {
				variable linedata
				return ${linedata(target)}
			}

			proc target2 { } {
				variable linedata
				return ${linedata(target2)}
			}

			# additional --

			# Returns any additional header elements beyond the target as a list.

			proc additional { } {
				variable linedata
				return ${linedata(additional)}
			}

			proc rawline { } {
				variable linedata
				return ${linedata(rawline)}
			}

			# header --

			# Returns the entire header in list format.

			proc header { } {
				variable linedata
				return [concat [list ${linedata(who)} {$linedata(action)} \
					${linedata(target)}] ${linedata(additional)}]
			}

			proc GetError { Message } {
				set RE_Closing	{ERROR\s:Closing\sLink:\s([^\[]+)\[([^\]]+)\]\s\((.*)\)}
				set DIE ""
				# connexion du services fermer par le serveur
				if { [regexp -nocase ${RE_Closing} ${Message} match hostname ip raison] } {
					if {[string match -nocase "*Authentication*failed*" ${raison}]} {
						set DIE	"Authentification du service '${hostname}' à échoué (mot de passe?)"
					} elseif {[string match -nocase "*SID*collision*" ${raison}]} {
						set DIE	"Le SID (Server ID) est déjà utiliser. Choisissez un autre."
					}

				}
				if { ${DIE} != ""} { die "\[Error - IRCServices\] ${DIE}" }

			}

			# GetEvent --

			# Get a line from the server and dispatch it.
			proc GetEvent { } {
				variable linedata
				variable sock
				variable dispatch
				variable [namespace current]::UID_DB
				array set linedata	{}
				set line "eof"
				if {
					[eof ${sock}] 											|| \
					[catch {gets ${sock} } line]
				} {
					close ${sock}
					set sock		{}
					cmd-log error "Error receiving from network: ${line}"
					if { [info exists dispatch(EOF)] } {
						eval ${dispatch(EOF)}
					}
					die "Error IRCServices: perte de la connexion au serveur"
					return
				}
				set line [string map { "\{" "\\\{" "\}" "\\\}" "\"" "\\\"" } ${line}]
				cmd-log debug "Recieved: ${line}"
				puts ${line}
				if { [string match -nocase "error*" [lindex ${line} 0]] } { GetError ${line} }
				if { [set pos [string first " :" ${line}]] > -1 } {
					set header				[string range ${line} 0 [expr {${pos} - 1}]]
					set linedata(msg)		[string range ${line} [expr {${pos} + 2}] end]

				} else {
					set header [string trim ${line}]
					set linedata(msg)		{}

				}
				if { [string match :* ${header}] } {
					set header				[split [string trimleft ${header} :]]
				} else {
					set header				[linsert [split ${header}] 0 {}]
				}
				set linedata(rawline)		${line}
				set linedata(who)			[lindex ${header} 0]
				set linedata(who2)			[[namespace current]::UID_CONVERT ${linedata(who)}]
				set linedata(action)		[lindex ${header} 1]
				set linedata(target)		[lindex ${header} 2]
				set linedata(target2)		[[namespace current]::UID_CONVERT ${linedata(target)}]
				set linedata(additional)	[lrange ${header} 3 end]
				set linedata(sid)			[namespace current]::network

				foreach t [namespace children] {
					set linedata(bid)			${t}::bot
					if { [info exists ${t}::dispatch(${linedata(action)})] } {
						catch {eval [set ${t}::dispatch(${linedata(action)})]}
					} elseif { [string match {[0-9]??} ${t}::dispatch(action)] } {
						eval [set ${t}::dispatch(defaultnumeric)]
					} elseif { ${linedata(who)} eq "" } {
						eval [set ${t}::dispatch(defaultcmd)]
					} else {
						eval [set ${t}::dispatch(defaultevent)]
					}
				}
				if { [info exists dispatch(${linedata(action)})] } {
					catch {eval $dispatch(${linedata(action)})}
				} elseif { [string match {[0-9]??} ${linedata(action)}] } {
					eval ${dispatch(defaultnumeric)}
				} elseif { ${linedata(who)} eq "" } {
					eval ${dispatch(defaultcmd)}
				} else {
					eval ${dispatch(defaultevent)}
				}
				if { [action] == "UID" } {
					# PROTOCOL TS6 : enregistre des ID<->nick en DB
					set uid				[string toupper [lindex [additional] 4]]
					set UID_DB([string toupper [target]])	${uid}
					set UID_DB([string toupper ${uid}])		[target]
				}
			}

			# registerevent --

			# Register an event in the dispatch table.

			# Arguments:
			# evnt: name of event as sent by IRC server.
			# cmd: proc to register as the event handler

			proc cmd-registerevent { evnt cmd } {
				variable dispatch
				set dispatch(${evnt}) ${cmd}
				if { ${cmd} eq "" } {
					unset dispatch(${evnt})
				}
			}

			# getevent --

			# Return the currently registered handler for the event.

			# Arguments:
			# evnt: name of event as sent by IRC server.

			proc cmd-getevent { evnt } {
				variable dispatch
				if { [info exists dispatch(${evnt})] } {
					return $dispatch(${evnt})
				}
				return {}
			}

			# eventexists --

			# Return a boolean value indicating if there is a handler
			# registered for the event.

			# Arguments:
			# evnt: name of event as sent by IRC server.

			proc cmd-eventexists { evnt } {
				variable dispatch
				return [info exists dispatch(${evnt})]
			}

			# network --

			# Accepts user commands and dispatches them.

			# Arguments:
			# cmd: command to invoke
			# args: arguments to the command

			proc network { cmd args } {
				if { [info proc [namespace current]::cmd-${cmd}] == "" } {
					return "sub-cmd inconnu. List: [join [string map [list "[namespace current]::cmd-" ""] [info proc [namespace current]::cmd-*]] ", "]"
				} else {
					eval [linsert ${args} 0 [namespace current]::cmd-${cmd}]
				}
			}

			# Create default handlers.

			set dispatch(PING) {network send "PONG :[msg]"}
			set dispatch(defaultevent) #
			set dispatch(defaultcmd) #
			set dispatch(defaultnumeric) #
		}


		set returncommand [format "%s::IRCServices%s::network" [namespace current] ${conn}]
		incr conn
		return ${returncommand}
	}

	# -------------------------------------------------------------------------

	package provide IRCServices ${::IRCServices::PKG(version)}
	# -------------------------------------------------------------------------
	return
