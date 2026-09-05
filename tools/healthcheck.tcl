#!/usr/bin/env tclsh
# Healthcheck statique ClaraServ — aucun réseau, aucun Eggdrop requis.
# Ne source PAS ClaraServ.tcl en mode auto-start.

proc usage {} {
    puts {Usage: tclsh tools/healthcheck.tcl [--help]

Contrôles:
  - présence fichiers essentiels
  - syntaxe Tcl (info complete) sans exécution réseau
  - structure des bases d'animations
  - détection références Eggdrop (informatif)
  - présence ClaraServ.conf (sans lire les secrets)

Codes: 0=OK (warnings OK), 1=échecs, 2=usage}
}

if {[llength $argv] > 0 && [lindex $argv 0] in {-h --help}} {
    usage
    exit 0
}

set scriptDir [file dirname [file normalize [info script]]]
set root [file dirname $scriptDir]
set ::HC_PASS 0
set ::HC_WARN 0
set ::HC_FAIL 0

proc hc_pass {msg} { puts "[format %-6s PASS] $msg"; incr ::HC_PASS }
proc hc_warn {msg} { puts "[format %-6s WARN] $msg"; incr ::HC_WARN }
proc hc_fail {msg} { puts "[format %-6s FAIL] $msg"; incr ::HC_FAIL }

puts "ClaraServ healthcheck (statique)"
puts "Racine: $root"
puts "Tcl: [info patchlevel]"
puts "------------------------------------------------------------"

# --- Tcl version ---
if {[package vcompare [info patchlevel] 8.6] >= 0} {
    hc_pass "Tcl >= 8.6 ([info patchlevel])"
} else {
    hc_fail "Tcl < 8.6 ([info patchlevel])"
}

# --- Fichiers essentiels ---
set required {
    ClaraServ.tcl
    ClaraServ.Example.conf
    modules/TCL-ZCT/ZCT.tcl
    modules/TCL-PKG-IRCServices/ircservices.tcl
    db/database.fr.db
    db/database.en.db
    tests/test_claraserv.tcl
}
foreach rel $required {
    set path [file join $root $rel]
    if {[file isfile $path]} {
        hc_pass "présent $rel"
    } else {
        hc_fail "manquant $rel"
    }
}

set conf [file join $root ClaraServ.conf]
if {[file isfile $conf]} {
    hc_warn "ClaraServ.conf présent (permissions/valeurs non affichées)"
    if {[catch {file attributes $conf -permissions} perm] == 0} {
        # octal string may vary; only warn if world-readable when detectable
        if {[string match *4 $perm] || [string match *5 $perm] || [string match *6 $perm] || [string match *7 $perm]} {
            # crude: if others bit set in last digit
            set last [string index $perm end]
            if {$last in {4 5 6 7}} {
                hc_warn "ClaraServ.conf potentiellement lisible par others (mode $perm)"
            }
        }
    }
} else {
    hc_pass "ClaraServ.conf absent (attendu hors déploiement)"
}

# --- Syntaxe Tcl sans exécution ---
proc check_tcl_syntax {path label} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set data [read $fh]
    close $fh
    if {[info complete $data]} {
        hc_pass "syntaxe Tcl complète: $label"
    } else {
        hc_fail "syntaxe Tcl incomplète (accolades?): $label"
    }
}

foreach {rel label} {
    ClaraServ.tcl ClaraServ.tcl
    modules/TCL-ZCT/ZCT.tcl ZCT.tcl
    modules/TCL-PKG-IRCServices/ircservices.tcl ircservices.tcl
    tests/test_claraserv.tcl test_claraserv.tcl
    ClaraServ.Example.conf ClaraServ.Example.conf
} {
    set path [file join $root $rel]
    if {[file isfile $path]} {
        check_tcl_syntax $path $label
    }
}

# --- Bases d'animations ---
proc validate_animation_db {path label} {
    set ns ::HC_DB_[clock clicks]
    namespace eval $ns {}
    if {[catch {namespace eval $ns [list source $path]} err]} {
        hc_fail "chargement $label: $err"
        namespace delete $ns
        return
    }
    if {![info exists ${ns}::database]} {
        hc_fail "$label: variable database absente"
        namespace delete $ns
        return
    }
    set database [set ${ns}::database]
    set count 0
    set errors 0
    set seen [dict create]
    foreach entry $database {
        incr count
        if {[llength $entry] != 3} {
            incr errors
            continue
        }
        set cmdWrap [lindex $entry 0]
        set level [lindex $entry 1]
        if {[llength $cmdWrap] != 1} {
            incr errors
            continue
        }
        set cmd [lindex $cmdWrap 0]
        if {![string match {!*} $cmd]} {
            incr errors
            continue
        }
        if {$level ni {0 1}} {
            incr errors
            continue
        }
        set key [string tolower $cmd]:$level
        if {[dict exists $seen $key]} {
            incr errors
            continue
        }
        dict set seen $key 1
    }
    namespace delete $ns
    if {$errors > 0} {
        hc_fail "$label: $errors entrée(s) invalide(s) sur $count"
    } elseif {$count == 0} {
        hc_fail "$label: catalogue vide"
    } else {
        hc_pass "$label: $count entrées valides"
        if {$count < 10} {
            hc_warn "$label: catalogue très petit ($count)"
        }
    }
}

validate_animation_db [file join $root db database.fr.db] database.fr.db
validate_animation_db [file join $root db database.en.db] database.en.db

# --- Primitives hôte bot absentes de ClaraServ.tcl (runtime pur tclsh) ---
set clara [file join $root ClaraServ.tcl]
if {[file isfile $clara]} {
    set fh [open $clara r]
    set src [read $fh]
    close $fh
    # Ignorer les commentaires de ligne.
    set codeOnly [regsub -all -line {#.*$} $src {}]
    set hits {}
    foreach pat {putlog binds unbind} {
        if {[regexp "\\m$pat\\M" $codeOnly]} {
            lappend hits $pat
        }
    }
    if {[llength $hits] == 0} {
        hc_pass "ClaraServ.tcl: aucune primitive hôte bot (putlog/binds/unbind)"
    } else {
        hc_fail "ClaraServ.tcl contient encore des primitives hôte bot: [join $hits {, }]"
    }
}

# --- Résolution packages modules (sans réseau, sans INIT) ---
# Lot 0 : cohérence pkgIndex ↔ package provide ↔ needZct/needIrcs ClaraServ.
proc read_pkgindex_version {pkgIndexPath packageName} {
    set fh [open $pkgIndexPath r]
    set data [read $fh]
    close $fh
    if {[regexp [format {package ifneeded %s ([0-9][^ \t\n]+)} $packageName] $data -> ver]} {
        return $ver
    }
    return {}
}

proc read_provide_version {tclPath} {
    set fh [open $tclPath r]
    set data [read $fh]
    close $fh
    if {[regexp {"version"\s+"([^"]+)"} $data -> ver]} {
        return $ver
    }
    return {}
}

proc read_claraserv_need {claraPath key} {
    set fh [open $claraPath r]
    set data [read $fh]
    close $fh
    if {[regexp [format {%s\s+"([^"]+)"} $key] $data -> ver]} {
        return $ver
    }
    return {}
}

proc assert_version_triple {label indexVer provideVer needVer} {
    if {$indexVer eq "" || $provideVer eq "" || $needVer eq ""} {
        hc_fail "$label: version manquante (pkgIndex='$indexVer' provide='$provideVer' need='$needVer')"
        return
    }
    if {$indexVer eq $provideVer && $provideVer eq $needVer} {
        hc_pass "$label: pkgIndex=provide=need=$provideVer"
    } else {
        hc_fail "$label: incohérence pkgIndex=$indexVer provide=$provideVer need=$needVer"
    }
}

set zctTcl [file join $root modules TCL-ZCT ZCT.tcl]
set zctIdx [file join $root modules TCL-ZCT pkgIndex.tcl]
set ircTcl [file join $root modules TCL-PKG-IRCServices ircservices.tcl]
set ircIdx [file join $root modules TCL-PKG-IRCServices pkgIndex.tcl]
set claraPath [file join $root ClaraServ.tcl]

set needZct [read_claraserv_need $claraPath needZct]
set needIrcs [read_claraserv_need $claraPath needIrcs]

if {[file isfile $zctTcl] && [file isfile $zctIdx] && [file isfile $claraPath]} {
    assert_version_triple ZCT \
        [read_pkgindex_version $zctIdx ZCT] \
        [read_provide_version $zctTcl] \
        $needZct
} else {
    hc_fail "ZCT: fichiers manquants pour contrôle de version"
}

if {[file isfile $ircTcl] && [file isfile $ircIdx] && [file isfile $claraPath]} {
    assert_version_triple IRCServices \
        [read_pkgindex_version $ircIdx IRCServices] \
        [read_provide_version $ircTcl] \
        $needIrcs
} else {
    hc_fail "IRCServices: fichiers manquants pour contrôle de version"
}

# Preuve : package require via pkgIndex local (sans auto_path global projet)
interp create ::HC_IDX
if {[catch {
    ::HC_IDX eval [list set dir [file normalize $zctIdx]]
    # dir must be the package directory containing pkgIndex
    ::HC_IDX eval [list set dir [file dirname [file normalize $zctIdx]]]
    ::HC_IDX eval {source [file join $dir pkgIndex.tcl]}
    ::HC_IDX eval [list package require ZCT $needZct]
    set ::HC_IDX_ZCT [::HC_IDX eval {package present ZCT}]
} idxErr]} {
    hc_fail "require ZCT $needZct via pkgIndex local: $idxErr"
} else {
    hc_pass "require ZCT via pkgIndex local → $::HC_IDX_ZCT (sans auto_path projet)"
}
interp delete ::HC_IDX

# Chargement réel comme ClaraServ (disableAutoStart) — aucun socket uplink
set loadNs ::HC_LOAD_[clock clicks]
if {[catch {
    namespace eval $loadNs {
        namespace eval ::ClaraServ { variable disableAutoStart 1 }
        source [file join $::root ClaraServ.tcl]
        set ::HC_ZCT_PRESENT [package present ZCT]
        set ::HC_IRC_PRESENT [package present IRCServices]
        set ::HC_CS_PRESENT [package present ClaraServ]
        set ::HC_AUTO_MODULES [lsearch -glob $::auto_path *modules*]
        set ::HC_NEED_ZCT $::ClaraServ::SCRIPT(needZct)
        set ::HC_NEED_IRCS $::ClaraServ::SCRIPT(needIrcs)
    }
} loadErr]} {
    hc_fail "chargement ClaraServ (disableAutoStart) : $loadErr"
} else {
    hc_pass "chargement local ZCT=$::HC_ZCT_PRESENT IRCServices=$::HC_IRC_PRESENT ClaraServ=$::HC_CS_PRESENT"
    if {$::HC_ZCT_PRESENT eq $::HC_NEED_ZCT && $::HC_IRC_PRESENT eq $::HC_NEED_IRCS} {
        hc_pass "versions runtime = needZct/needIrcs ($::HC_NEED_ZCT / $::HC_NEED_IRCS)"
    } else {
        hc_fail "runtime ZCT=$::HC_ZCT_PRESENT/need=$::HC_NEED_ZCT IRC=$::HC_IRC_PRESENT/need=$::HC_NEED_IRCS"
    }
    if {$::HC_AUTO_MODULES < 0} {
        hc_pass "auto_path ne contient pas modules/ (source relatif confirmé)"
    } else {
        hc_warn "auto_path contient une entrée modules/ (index $::HC_AUTO_MODULES)"
    }
}

# setup.tcl / outils amont ne sont pas requis au runtime
if {[file isfile [file join $root modules TCL-PKG-IRCServices setup.tcl]]} {
    hc_warn "setup.tcl présent mais non requis au runtime ClaraServ"
} else {
    hc_pass "setup.tcl absent (attendu après nettoyage modules)"
}

# --- Note stratégie stubs ---
hc_pass "stratégie: ne pas source ClaraServ.tcl sans disableAutoStart (évite connect uplink)"
hc_pass "pkgIndex = métadonnées de cohérence ; runtime reste source relatif"

# --- Préflight labo S2S (statique, hors réseau) ---
hc_warn "TLS uplink: IRCServices utilise tls::socket -require 0 -request 0 (pas de validation CA client)"
hc_warn "Ne jamais activer uplink_debug=1 hors labo court : le trafic send (PASS) peut être journalisé"
if {[file isfile [file join $root docs UNREALIRCD.md]]} {
    hc_pass "Doc S2S Unreal: docs/UNREALIRCD.md"
} else {
    hc_fail "docs/UNREALIRCD.md manquant"
}

puts "------------------------------------------------------------"
puts "Résumé: PASS=$::HC_PASS WARN=$::HC_WARN FAIL=$::HC_FAIL"
if {$::HC_FAIL > 0} {
    exit 1
}
exit 0
