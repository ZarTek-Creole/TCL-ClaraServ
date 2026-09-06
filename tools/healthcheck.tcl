#!/usr/bin/env tclsh
# Healthcheck produit ClaraServ — un seul point d’entrée, hors réseau.
# Enchaîne : bash -n scripts · validate-animations-db · contrôles Tcl.
# Ne source PAS ClaraServ.tcl sans disableAutoStart.

proc usage {} {
    puts {Usage: tclsh tools/healthcheck.tcl [--help]

Contrôles (sans connexion IRC) :
  - bash -n (et shellcheck si présent) sur bin/claraserv-screen
  - tools/validate-animations-db.tcl
  - présence / syntaxe / packages / chargement disableAutoStart

Codes: 0=OK (WARN autorisés), 1=FAIL, 2=usage}
}

if {[llength $argv] > 0 && [lindex $argv 0] in {-h --help}} {
    usage
    exit 2
}

set scriptDir [file dirname [file normalize [info script]]]
set root [file dirname $scriptDir]
set ::HC_PASS 0
set ::HC_WARN 0
set ::HC_FAIL 0

proc hc_pass {msg} { puts "[format %-6s PASS] $msg"; incr ::HC_PASS }
proc hc_warn {msg} { puts "[format %-6s WARN] $msg"; incr ::HC_WARN }
proc hc_fail {msg} { puts "[format %-6s FAIL] $msg"; incr ::HC_FAIL }

puts "ClaraServ healthcheck"
puts "Racine: $root"
puts "Tcl: [info patchlevel]"
puts "------------------------------------------------------------"

# --- Tcl version ---
if {[package vcompare [info patchlevel] 8.6] >= 0} {
    hc_pass "Tcl >= 8.6 ([info patchlevel])"
} else {
    hc_fail "Tcl < 8.6 ([info patchlevel])"
}

# --- Shell : bash -n (+ shellcheck optionnel) ---
set screenSh [file join $root bin claraserv-screen]
if {[file isfile $screenSh]} {
    if {[catch {exec bash -n $screenSh} err]} {
        hc_fail "bash -n bin/claraserv-screen: $err"
    } else {
        hc_pass "bash -n bin/claraserv-screen"
    }
    if {[llength [auto_execok shellcheck]]} {
        if {[catch {exec shellcheck -x $screenSh} scErr]} {
            hc_warn "shellcheck bin/claraserv-screen: $scErr"
        } else {
            hc_pass "shellcheck bin/claraserv-screen"
        }
    }
} else {
    hc_fail "manquant bin/claraserv-screen"
}

# --- Validateur DB (contenu) ---
puts ""
puts "--- validate-animations-db.tcl ---"
set valScript [file join $scriptDir validate-animations-db.tcl]
if {![file isfile $valScript]} {
    hc_fail "manquant tools/validate-animations-db.tcl"
} elseif {[catch {exec tclsh $valScript} valOut]} {
    puts $valOut
    hc_fail "validate-animations-db.tcl a échoué"
} else {
    if {$valOut ne ""} { puts $valOut }
    hc_pass "validate-animations-db.tcl OK"
}
puts ""

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
        set last [string index $perm end]
        if {$last in {4 5 6 7}} {
            hc_warn "ClaraServ.conf potentiellement lisible par others (mode $perm)"
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

foreach rel {
    db/aliases.fr.db
    db/variants.fr.db
    db/fails.fr.db
} {
    set path [file join $root $rel]
    if {[file isfile $path]} {
        hc_pass "présent $rel"
    } else {
        hc_warn "absent (optionnel): $rel"
    }
}

# --- Primitives hôte bot absentes ---
set clara [file join $root ClaraServ.tcl]
if {[file isfile $clara]} {
    set fh [open $clara r]
    set src [read $fh]
    close $fh
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

# --- Versions packages ---
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

interp create ::HC_IDX
if {[catch {
    ::HC_IDX eval [list set dir [file dirname [file normalize $zctIdx]]]
    ::HC_IDX eval {source [file join $dir pkgIndex.tcl]}
    ::HC_IDX eval [list package require ZCT $needZct]
    set ::HC_IDX_ZCT [::HC_IDX eval {package present ZCT}]
} idxErr]} {
    hc_fail "require ZCT $needZct via pkgIndex local: $idxErr"
} else {
    hc_pass "require ZCT via pkgIndex local → $::HC_IDX_ZCT"
}
interp delete ::HC_IDX

if {[catch {
    namespace eval ::ClaraServ { variable disableAutoStart 1 }
    source [file join $root ClaraServ.tcl]
    set ::HC_ZCT_PRESENT [package present ZCT]
    set ::HC_IRC_PRESENT [package present IRCServices]
    set ::HC_CS_PRESENT [package present ClaraServ]
    set ::HC_AUTO_MODULES [lsearch -glob $::auto_path *modules*]
    set ::HC_NEED_ZCT $::ClaraServ::SCRIPT(needZct)
    set ::HC_NEED_IRCS $::ClaraServ::SCRIPT(needIrcs)
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
        hc_pass "auto_path ne contient pas modules/"
    } else {
        hc_warn "auto_path contient une entrée modules/ (index $::HC_AUTO_MODULES)"
    }
}

if {[file isfile [file join $root modules TCL-PKG-IRCServices setup.tcl]]} {
    hc_warn "setup.tcl présent mais non requis au runtime"
} else {
    hc_pass "setup.tcl absent"
}

hc_warn "TLS uplink: tls::socket -require 0 -request 0 (pas de validation CA client)"
hc_warn "Ne jamais activer uplink_debug=1 hors labo court"
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
}
