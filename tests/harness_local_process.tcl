#!/usr/bin/env tclsh
# tests/harness_local_process.tcl
# HARNESS DE TEST UNIQUEMENT — ne pas utiliser en production.
# Charge ClaraServ avec disableAutoStart, installe le lifecycle standalone,
# attend un stop-file, quitte avec exitCode. Aucune connexion IRC.

if {![info exists ::env(CLARASERV_TEST_LOCAL_PROCESS)] || $::env(CLARASERV_TEST_LOCAL_PROCESS) ne "1"} {
    puts stderr "refus: CLARASERV_TEST_LOCAL_PROCESS=1 requis (harness test-only)"
    exit 2
}
if {![info exists ::env(CLARASERV_TEST_RUNTIME_DIR)] || [string trim $::env(CLARASERV_TEST_RUNTIME_DIR)] eq ""} {
    puts stderr "refus: CLARASERV_TEST_RUNTIME_DIR (absolu) requis"
    exit 2
}

set runtimeDir [file normalize [string trim $::env(CLARASERV_TEST_RUNTIME_DIR)]]
if {[file pathtype $runtimeDir] ne "absolute"} {
    puts stderr "refus: CLARASERV_TEST_RUNTIME_DIR doit être absolu ($runtimeDir)"
    exit 2
}
if {![file isdirectory $runtimeDir]} {
    if {[catch {file mkdir $runtimeDir} err]} {
        puts stderr "refus: impossible de créer runtime_dir: $err"
        exit 2
    }
}

set harnessDir [file dirname [file normalize [info script]]]
set projectDir [file dirname $harnessDir]

namespace eval ::ClaraServ {
    variable disableAutoStart 1
}
if {[catch {source [file join $projectDir ClaraServ.tcl]} err options]} {
    puts stderr "chargement ClaraServ impossible: $err"
    puts stderr [dict get $options -errorinfo]
    exit 1
}

# Garde réseau : toute tentative de connexion échoue immédiatement.
if {[info commands ::ClaraServ::FCT::Create:Service] ne ""} {
    rename ::ClaraServ::FCT::Create:Service ::ClaraServ::FCT::Create:Service:HarnessOrig
    proc ::ClaraServ::FCT::Create:Service {args} {
        return -code error "NETWORK_FORBIDDEN: Create:Service interdit dans le harness local-process"
    }
}
if {[info commands ::IRCServices::connection] ne ""} {
    rename ::IRCServices::connection ::IRCServices::connection:HarnessOrig
    proc ::IRCServices::connection {args} {
        return -code error "NETWORK_FORBIDDEN: IRCServices::connection interdit dans le harness local-process"
    }
}

set ::ClaraServ::config(runtime_dir) $runtimeDir
set ::ClaraServ::CONNECT_ID {}
set ::ClaraServ::BOT_ID {}
set ::ClaraServ::shutdown 0
set ::ClaraServ::exitCode 0
set ::ClaraServ::shuttingDown 0

if {[catch {::ClaraServ::FCT::Install:Standalone:Controls} ctrlErr]} {
    ::ClaraServ::log error $ctrlErr
    exit 1
}

# Signal de readiness contrôlé (fichier + log non sensible).
set readyFile [file join $runtimeDir claraserv.ready]
set rf [open $readyFile w]
try {
    puts $rf "ready"
} finally {
    close $rf
}
::ClaraServ::log info "TEST_LOCAL_PROCESS_READY"

if {!$::ClaraServ::shuttingDown} {
    vwait ::ClaraServ::shutdown
}

if {[info exists ::ClaraServ::pidFile] && $::ClaraServ::pidFile ne "" && [file exists $::ClaraServ::pidFile]} {
    catch {file delete -force $::ClaraServ::pidFile}
}

set code 0
if {[info exists ::ClaraServ::exitCode]} {
    set code $::ClaraServ::exitCode
}
exit $code
