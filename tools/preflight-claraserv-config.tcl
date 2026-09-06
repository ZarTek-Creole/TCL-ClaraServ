#!/usr/bin/env tclsh
# tools/preflight-claraserv-config.tcl
# Préflight structurel de ClaraServ.conf — AUCUNE valeur sensible affichée.
# Aucune socket, aucun réseau, aucun effet de bord runtime.

proc usage {} {
    puts {Usage: tclsh tools/preflight-claraserv-config.tcl [--help]

Contrôle structurel local de ClaraServ.conf (PASS/WARN/FAIL).
N’imprime jamais les valeurs de configuration.
N’ouvre aucune connexion IRC/S2S.

Codes: 0=OK (WARN autorisés), 1=FAIL, 2=usage/fichier absent}
}

if {[llength $argv] > 0 && [lindex $argv 0] in {-h --help}} {
    usage
    exit 2
}

set scriptDir [file dirname [file normalize [info script]]]
set root [file dirname $scriptDir]
set conf [file join $root ClaraServ.conf]

set ::PF_PASS 0
set ::PF_WARN 0
set ::PF_FAIL 0

proc pf_pass {msg} { puts "[format %-6s PASS] $msg"; incr ::PF_PASS }
proc pf_warn {msg} { puts "[format %-6s WARN] $msg"; incr ::PF_WARN }
proc pf_fail {msg} { puts "[format %-6s FAIL] $msg"; incr ::PF_FAIL }

puts "ClaraServ preflight-config (aucune valeur affichée)"
puts "Racine: $root"
puts "------------------------------------------------------------"
puts "Limite: source Tcl isolé ; socket/exec/tls::socket refusés ; valeurs jamais affichées."

if {![file exists $conf]} {
    pf_fail "ClaraServ.conf absent — copiez ClaraServ.Example.conf et renseignez les valeurs labo"
    puts "------------------------------------------------------------"
    puts "Résumé: PASS=$::PF_PASS WARN=$::PF_WARN FAIL=$::PF_FAIL"
    exit 2
}

set mode [file attributes $conf -permissions]
set other [string index $mode end]
if {$other eq "0"} {
    pf_pass "ClaraServ.conf présent (non lisible par others)"
} else {
    pf_warn "ClaraServ.conf permissions mode=$mode — recommandé 0600"
}

# Interpréteur isolé : refuser réseau / exec ; garder open pour source de la conf.
interp create ::PF
::PF eval { namespace eval ::cfg { array set config {} } }
foreach cmd {socket exec fileevent vwait} {
    catch {::PF hide $cmd}
}
# Bloquer création de socket TLS dans l’enfant
::PF eval {
    namespace eval ::tls {}
    proc ::tls::socket {args} {
        return -code error "PREFLIGHT_DENIED"
    }
}

set loadOk 1
if {[catch {
    ::PF eval [list namespace eval ::cfg [list source $conf]]
} loadErr]} {
    set loadOk 0
    if {[string match *PREFLIGHT_DENIED* $loadErr]} {
        pf_fail "chargement conf a tenté un effet de bord interdit"
    } else {
        pf_fail "chargement ClaraServ.conf impossible (erreur Tcl de structure/syntaxe)"
    }
}

proc pf_has {key} {
    return [::PF eval [list info exists ::cfg::config($key)]]
}
proc pf_get {key} {
    return [::PF eval [list set ::cfg::config($key)]]
}
proc pf_looks_placeholder {val} {
    set v [string trim $val]
    if {$v eq ""} { return 1 }
    if {[regexp {^<.*>$} $v]} { return 1 }
    if {[string match "IRCD_*" $v]} { return 1 }
    if {[string match "CLARASERV_*" $v]} { return 1 }
    if {[string match "*CHANGE_ME*" $v]} { return 1 }
    if {[string match -nocase "*your-password*" $v]} { return 1 }
    if {[string match -nocase "*votre-mot*" $v]} { return 1 }
    if {[string match -nocase "*mypassword*" $v]} { return 1 }
    if {$v in {
        IRCD_HOST_OR_LOOPBACK IRCD_S2S_TLS_PORT CLARASERV_LINK_PASSWORD
        CLARASERV_SERVICE_NAME CLARASERV_SERVICE_SID CA_FILE_OR_CERT_POLICY
    }} {
        return 1
    }
    return 0
}

if {$loadOk} {
    pf_pass "ClaraServ.conf chargé dans interpréteur isolé (sans réseau)"

    set required {
        uplink_host uplink_ssl uplink_port uplink_password
        serverinfo_name serverinfo_descr serverinfo_id
        uplink_useprivmsg uplink_debug
        service_nick service_user service_host service_gecos service_modes
        service_channel service_chanmodes service_usermodes
        admin_password log_command db_lang
    }
    foreach key $required {
        if {![pf_has $key]} {
            pf_fail "clé absente: config($key)"
            continue
        }
        set val [pf_get $key]
        if {[string trim $val] eq ""} {
            pf_fail "clé vide: config($key)"
            continue
        }
        if {[pf_looks_placeholder $val]} {
            pf_fail "placeholder ou valeur d’exemple détectée: config($key)"
            continue
        }
        pf_pass "clé présente et non-placeholder: config($key)"
    }

    if {[pf_has uplink_port]} {
        set p [pf_get uplink_port]
        if {![string is integer -strict $p] || $p < 1 || $p > 65535} {
            pf_fail "config(uplink_port) doit être un entier 1–65535"
        } else {
            pf_pass "config(uplink_port) numérique valide"
        }
    }

    foreach key {uplink_ssl uplink_useprivmsg uplink_debug log_command} {
        if {[pf_has $key]} {
            set b [pf_get $key]
            if {![string is boolean -strict $b]} {
                pf_fail "config($key) doit être booléen 0/1"
            } else {
                pf_pass "config($key) booléen valide"
            }
        }
    }

    if {[pf_has uplink_ssl] && [string is true -strict [pf_get uplink_ssl]]} {
        if {[catch {package require tls 1.7.16}]} {
            pf_fail "TLS activé (uplink_ssl) mais package tls indisponible"
        } else {
            pf_pass "TLS activé et package tls disponible"
        }
    } elseif {[pf_has uplink_ssl]} {
        pf_warn "TLS désactivé (uplink_ssl faux) — labo S2S TLS attendu normalement"
    }

    if {[pf_has uplink_debug] && [string is true -strict [pf_get uplink_debug]]} {
        pf_fail "config(uplink_debug) actif — risque de journaliser PASS ; mettre à 0"
    } elseif {[pf_has uplink_debug]} {
        pf_pass "config(uplink_debug) désactivé"
    }

    if {[pf_has serverinfo_id]} {
        set sid [string trim [pf_get serverinfo_id]]
        if {$sid eq ""} {
            pf_warn "config(serverinfo_id) vide — mode non-TS6 (inadapté Unreal moderne)"
        } elseif {![regexp {^[0-9][0-9A-Z]{2}$} $sid]} {
            pf_fail {config(serverinfo_id) syntaxe SID invalide (attendu forme [0-9][0-9A-Z]{2})}
        } else {
            pf_pass "config(serverinfo_id) syntaxe SID plausible"
        }
    }

    if {[pf_has service_channel]} {
        set ch [pf_get service_channel]
        if {![regexp {^#[^[:space:]\x00-\x1f,:]{1,50}$} $ch]} {
            pf_fail "config(service_channel) nom de salon invalide"
        } else {
            pf_pass "config(service_channel) syntaxe salon OK"
        }
    }

    if {[pf_has service_chanmodes]} {
        set modes [string trim [pf_get service_chanmodes]]
        if {$modes eq ""} {
            pf_pass "config(service_chanmodes) vide (aucun MODE forcé au join — adapté salon public)"
        } elseif {[string match "*O*" $modes]} {
            # Unreal +O = salon réservé aux IRCops — bloque Kiwi / users normaux
            pf_warn "config(service_chanmodes) contient +O (IRCops only) — inadapté à un salon public/accueil ; préférer \"\" ou +nt"
        } else {
            pf_pass "config(service_chanmodes) défini (sans +O)"
        }
    }

    if {[pf_has db_lang]} {
        set lang [string tolower [pf_get db_lang]]
        set dbfile [file join $root db database.$lang.db]
        if {[file isfile $dbfile]} {
            pf_pass "base animations présente pour db_lang"
        } else {
            pf_fail "base animations absente pour db_lang"
        }
    }

    if {[pf_has runtime_dir]} {
        set rd [string trim [pf_get runtime_dir]]
        if {$rd ne "" && [pf_looks_placeholder $rd]} {
            pf_fail "config(runtime_dir) ressemble à un placeholder"
        } elseif {$rd ne ""} {
            pf_pass "config(runtime_dir) défini"
        }
    } else {
        pf_pass "config(runtime_dir) absent — défaut <racine>/run"
    }

    if {[pf_has service_host] && [pf_has serverinfo_name]} {
        if {[string equal -nocase [pf_get service_host] [pf_get serverinfo_name]]} {
            pf_pass "service_host aligné sur serverinfo_name"
        } else {
            pf_warn "service_host ≠ serverinfo_name — vérifier intention"
        }
    }
}

interp delete ::PF

puts "------------------------------------------------------------"
puts "Résumé: PASS=$::PF_PASS WARN=$::PF_WARN FAIL=$::PF_FAIL"
if {$::PF_FAIL > 0} {
    exit 1
}
exit 0
