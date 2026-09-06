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
		"version"			"0.1.0"
		"need_tcl"			"8.6"
		"need_tls"			"1.7.16"
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

			if {[catch {package require ZCT ${PKG(need_zct)}} err]} {
			return -code error "${PKG(name)} nécessite ZCT ${PKG(need_zct)} ou supérieur : $err"
		}
		namespace import -force ::ZCT::*

	pkg load Tcl ${PKG(need_tcl)} ${PKG(name)}
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

		proc TLSSocketCallBack { level args } {
			set SOCKET_NAME	[lindex ${args} 0]
			set type		[lindex ${args} 1]
			set socketid	[lindex ${args} 2]
			set what		[lrange ${args} 3 end]
			cmd-log debug "Socket '${SOCKET_NAME}' callback ${type}: ${what}"
							if {[string match -nocase "*certificate*verify*failed*" $what]} {
					cmd-log error "Échec de vérification TLS pour $SOCKET_NAME : $what"
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
							if {[catch {
					puts $sock $msg
					flush $sock
				} err]} {
					catch {close $sock}
					set sock {}
					if {[info exists dispatch(EOF)]} {
						catch {namespace eval [namespace current] $dispatch(EOF)} callbackError
						if {$callbackError ne ""} {cmd-log error "EOF callback failed: $callbackError"}
					}
					cmd-log error "Error sending to IRC network: $err"
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
			if {[llength $args] == 0} {
				return [array get config]
			}
			if {[llength $args] == 1} {
				set key [lindex $args 0]
				if {![info exists config($key)]} {
					return -code error "unknown configuration option: $key"
				}
				return $config($key)
			}
			if {[llength $args] != 2} {
				return -code error "wrong # args: should be \"config key ?value?\""
			}
			set config([lindex $args 0]) [lindex $args 1]
		}

		proc cmd-log {level text} {
			variable config
			if {$level eq "debug" && !$config(debug)} {
				return
			}
			if {$level ne "error" && !$config(logger) && !$config(debug)} {
				return
			}
			puts stderr [format {[IRCServices][%s] %s} [string toupper $level] $text]
		}

		proc cmd-logname {} {
			return {}
		}


		# cmd-destroy --
		#
		# destroys the current connection and its namespace

		proc cmd-destroy {} {
			variable sock
			catch {close $sock}
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

			proc cmd-connect {hostname port password {ts6 1} {name eva.info} {id 00R} {description "Services for IRC Networks"}} {
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
							if {$secure} {
					if {[catch {package require tls ${PKG(need_tls)}} tlsError]} {
						return -code error "${PKG(name)} nécessite tls ${PKG(need_tls)} ou supérieur : $tlsError"
					}
				}
				if {$sock eq ""} {
					if {$secure} {
						set callback [list [namespace current]::TLSSocketCallBack]
						set socketCommand [list ::tls::socket -require 0 -request 0 -command $callback $host $port]
					} else {
						set socketCommand [list ::socket $host $port]
					}
					if {[catch {set sock [{*}$socketCommand]} err]} {
						return -code error "Impossible de se connecter à $host:$port : $err"
					}
					fconfigure $sock -translation crlf -buffering line -encoding utf-8 -blocking 0
					fileevent $sock readable [namespace current]::GetEvent

					if { ${ts6} } {
						send "PASS :${pass}"
						send "PROTOCTL NICKv2 VHP UMODE2 NICKIP SJOIN SJOIN2 SJ3 NOQUIT TKLEXT MLOCK SID"
						send "PROTOCTL EAUTH=${sname},,,IRCService-${PKG(version)}"
						send "PROTOCTL SID=${sid}"
							send ":${sid} SERVER ${sname} 1 :${description}"
						send "EOS"
					} else {
						send "PASS ${pass}"
							send "SERVER ${sname} 1 :${description}"
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

			proc GetError {message} {
				set closingPattern {ERROR\s*:Closing\s+Link:\s*([^\[]+)\[([^\]]+)\]\s*\((.*)\)}
				if {![regexp -nocase $closingPattern $message -> hostname ip reason]} {
					return -code error "Erreur IRC reçue : $message"
				}
				if {[string match -nocase "*Authentication*failed*" $reason]} {
					return -code error "Authentification du service refusée par $hostname ($ip). Vérifiez uplink_password."
				}
				if {[string match -nocase "*SID*collision*" $reason]} {
					return -code error "Collision de SID signalée par $hostname ($ip). Choisissez un autre serverinfo_id."
				}
				return -code error "Connexion refusée par $hostname ($ip) : $reason"
			}

			# GetEvent --
			# Lit une ligne IRC complète, puis distribue l’événement. Les données
			# réseau ne sont jamais interprétées comme une liste Tcl.
			proc GetEvent {} {
				variable linedata
				variable sock
				variable dispatch
				variable [namespace current]::UID_DB

				if {$sock eq ""} {
					return
				}
				set bytesRead [gets $sock line]
				if {$bytesRead < 0} {
					if {![eof $sock]} {
						return
					}
					catch {close $sock}
					set sock {}
					cmd-log error "Connexion IRC fermée par le pair."
					if {[info exists dispatch(EOF)] && $dispatch(EOF) ne ""} {
						catch {namespace eval [namespace current] $dispatch(EOF)} callbackError
						if {$callbackError ne ""} {cmd-log error "EOF callback failed: $callbackError"}
					}
					return
				}

				cmd-log debug "Received: $line"
				if {[regexp -nocase {^ERROR(?:\s|$)} $line]} {
					if {[catch {GetError $line} errorMessage]} {
						cmd-log error $errorMessage
					}
					# Permettre à ClaraServ (et autres) d’arrêter proprement sur ERROR uplink.
					if {[info exists dispatch(ERROR)] && $dispatch(ERROR) ne ""} {
						if {[catch {namespace eval [namespace current] $dispatch(ERROR)} callbackError]} {
							cmd-log error "ERROR callback failed: $callbackError"
						}
					}
					return
				}

				array unset linedata
				set trailingPosition [string first " :" $line]
				if {$trailingPosition >= 0} {
					set headerText [string range $line 0 [expr {$trailingPosition - 1}]]
					set linedata(msg) [string range $line [expr {$trailingPosition + 2}] end]
				} else {
					set headerText [string trim $line]
					set linedata(msg) {}
				}

				set headerWords [regexp -all -inline {\S+} $headerText]
				if {[string match :* $headerText]} {
					set headerWords [lreplace $headerWords 0 0 [string trimleft [lindex $headerWords 0] :]]
				} else {
					set headerWords [linsert $headerWords 0 {}]
				}

				set linedata(rawline) $line
				set linedata(who) [lindex $headerWords 0]
				set linedata(who2) [[namespace current]::UID_CONVERT $linedata(who)]
				set linedata(action) [lindex $headerWords 1]
				set linedata(target) [lindex $headerWords 2]
				set linedata(target2) [[namespace current]::UID_CONVERT $linedata(target)]
				set linedata(additional) [lrange $headerWords 3 end]
				set linedata(sid) [namespace current]::network

				foreach childNamespace [namespace children] {
					set linedata(bid) ${childNamespace}::bot
					if {[info exists ${childNamespace}::dispatch($linedata(action))]} {
						set callback [set ${childNamespace}::dispatch($linedata(action))]
					} elseif {[string match {[0-9]??} $linedata(action)]} {
						set callback [set ${childNamespace}::dispatch(defaultnumeric)]
					} elseif {$linedata(who) eq ""} {
						set callback [set ${childNamespace}::dispatch(defaultcmd)]
					} else {
						set callback [set ${childNamespace}::dispatch(defaultevent)]
					}
					if {$callback ne "" && [catch {namespace eval [namespace current] $callback} callbackError]} {
						cmd-log error "Callback $linedata(action) failed: $callbackError"
					}
				}

				if {[info exists dispatch($linedata(action))]} {
					set callback $dispatch($linedata(action))
				} elseif {[string match {[0-9]??} $linedata(action)]} {
					set callback $dispatch(defaultnumeric)
				} elseif {$linedata(who) eq ""} {
					set callback $dispatch(defaultcmd)
				} else {
					set callback $dispatch(defaultevent)
				}
				if {$callback ne "" && [catch {namespace eval [namespace current] $callback} callbackError]} {
					cmd-log error "Network callback $linedata(action) failed: $callbackError"
				}

				if {$linedata(action) eq "UID" && [llength $linedata(additional)] >= 5} {
					set uid [string toupper [lindex $linedata(additional) 4]]
					set UID_DB([string toupper $linedata(target)]) $uid
					set UID_DB([string toupper $uid]) $linedata(target)
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
