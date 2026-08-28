#!/usr/bin/env tclsh

set testDirectory [file dirname [file normalize [info script]]]
set projectDirectory [file dirname $testDirectory]
set failures 0

proc assertEqual {expected actual description} {
    global failures
    if {$expected ne $actual} {
        incr failures
        puts stderr "FAIL: $description\n  expected: <$expected>\n  actual:   <$actual>"
        return
    }
    puts "PASS: $description"
}

proc assertTrue {condition description} {
    global failures
    if {![uplevel 1 [list expr $condition]]} {
        incr failures
        puts stderr "FAIL: $description"
        return
    }
    puts "PASS: $description"
}

namespace eval ::TestBot {
    variable messages {}
}

proc ::TestBot {subcommand args} {
    variable ::TestBot::messages
    lappend messages [linsert $args 0 $subcommand]
}

namespace eval ::ClaraServ {
    variable disableAutoStart 1
}
if {[catch {source [file join $projectDirectory ClaraServ.tcl]} errorMessage options]} {
    puts stderr "FAIL: chargement de ClaraServ: $errorMessage"
    puts stderr [dict get $options -errorinfo]
    exit 1
}

# Chargement et indexation des animations embarquées.
set animationFile [file join $projectDirectory db database.fr.db]
namespace eval ::ClaraServ [list source $animationFile]
::ClaraServ::FCT::DB:Index
assertTrue {[llength [::ClaraServ::FCT::DB:CMD:LIST]] > 70} "L’index contient les animations françaises"
assertTrue {[::ClaraServ::FCT::DB:GET !gaufre 0] ne "-1"} "La réponse sans cible est indexée"
assertTrue {[::ClaraServ::FCT::DB:GET !gaufre 1] ne "-1"} "La réponse avec cible est indexée"
assertEqual "-1" [::ClaraServ::FCT::DB:GET !inconnue 0] "Une commande absente ne renvoie aucune animation"

# Issue #10 : une accolade non appariée dans un PRIVMSG ne doit jamais être
# interprétée comme une syntaxe Tcl et doit être transmise comme pseudonyme.
set ::TestBot::messages {}
set ::ClaraServ::BOT_ID ::TestBot
set ::ClaraServ::config(uplink_useprivmsg) 1
set ::ClaraServ::config(service_channel) #services
set ::ClaraServ::config(log_command) 0
set ::ClaraServ::config(service_nick) ClaraServ
set unmatchedOpenBrace [format %c 123]
set result [::ClaraServ::FCT::Dispatch:Message Alice #lounge "!gaufre $unmatchedOpenBrace"]
assertEqual "1" $result "Un message contenant une accolade non appariée est traité"
assertTrue {[llength $::TestBot::messages] == 1} "L’animation est envoyée une seule fois"
set sentMessage [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first $unmatchedOpenBrace $sentMessage] >= 0} "Le pseudonyme avec accolade est conservé sans erreur Tcl"

# Validation de configuration : la valeur d’exemple ne peut plus démarrer le service.
foreach key $::ClaraServ::config(requiredKeys) {
    set ::ClaraServ::config($key) value
}
array set ::ClaraServ::config {
    uplink_ssl 0
    uplink_port 7000
    uplink_useprivmsg 1
    uplink_debug 0
    log_command 0
    serverinfo_id 00C
    service_channel #services
    admin_password votre-mot-2-pass
}
assertTrue {[catch {::ClaraServ::FCT::Check:Config}]} "Le mot de passe administrateur d’exemple est rejeté"
set ::ClaraServ::config(admin_password) aStrongPassword
assertEqual "" [::ClaraServ::FCT::Check:Config] "Une configuration minimale valide est acceptée"

# Stockage des salons : égalité littérale et réécriture atomique.
set temporaryDirectory [file normalize [file join $testDirectory tmp-[pid]]]
file mkdir [file join $temporaryDirectory db]
set originalDirectory $::ClaraServ::SCRIPT(dirname)
set ::ClaraServ::SCRIPT(dirname) $temporaryDirectory
set salonFile [file join $temporaryDirectory db salon.db]
close [open $salonFile w]
assertEqual "1" [::ClaraServ::FCT::DB:SALON:ADD #test] "Un salon IRC valide est ajouté"
assertEqual "-1" [::ClaraServ::FCT::DB:SALON:ADD #test] "Un salon ne peut pas être ajouté deux fois"
assertEqual "0" [::ClaraServ::FCT::DB:SALON:ADD "#test *"] "Un salon contenant un espace est rejeté"
assertEqual "1" [::ClaraServ::FCT::DB:DATA:EXIST salon #test] "La recherche de salon est une égalité exacte"
assertEqual "1" [::ClaraServ::FCT::DB:DATA:REMOVE salon #test] "Un salon enregistré est retiré"
assertEqual "0" [::ClaraServ::FCT::DB:DATA:EXIST salon #test] "Le salon retiré n’est plus présent"
set ::ClaraServ::SCRIPT(dirname) $originalDirectory
file delete -force $temporaryDirectory

# IRCServices : test d’intégration avec une maquette TCP locale. Le client doit
# recevoir un PRIVMSG contenant une accolade non appariée sans mettre fin au
# gestionnaire d’événement.
namespace eval ::TestNetwork {
    variable lines {}
    variable received ""
    variable completed 0
    variable timedOut 0
}

proc ::TestNetwork::accept {channel address port} {
    fconfigure $channel -blocking 0 -buffering line -translation crlf -encoding utf-8
    fileevent $channel readable [list ::TestNetwork::read $channel]
}

proc ::TestNetwork::read {channel} {
    variable lines
    set openBrace [format %c 123]
    while {[gets $channel line] >= 0} {
        lappend lines $line
        if {$line eq "EOS"} {
            puts $channel [format {:%s PRIVMSG #lounge :!gaufre %s} Alice!user@example.test $openBrace]
            flush $channel
        }
    }
}

set server [socket -server ::TestNetwork::accept 0]
set serverPort [lindex [fconfigure $server -sockname] 2]
set ircConnection [::IRCServices::connection]
set ircBot [$ircConnection bot]
$ircBot registerevent PRIVMSG {
    set ::TestNetwork::received [msg]
    set ::TestNetwork::completed 1
}
$ircConnection connect 127.0.0.1 $serverPort test-password 0 test.example.net {} "Test service"
after 5000 {
    set ::TestNetwork::timedOut 1
    set ::TestNetwork::completed 1
}
vwait ::TestNetwork::completed
assertEqual "0" $::TestNetwork::timedOut "La maquette IRC répond dans le délai de test"
assertEqual "!gaufre [format %c 123]" $::TestNetwork::received "IRCServices préserve le message avec accolade non appariée"
assertTrue {[lsearch -exact $::TestNetwork::lines "SERVER test.example.net 1 :Test service"] >= 0} "La description serveur configurée est transmise"
$ircConnection destroy
close $server

if {$failures > 0} {
    puts stderr "\n$failures échec(s) de test."
    exit 1
}
puts "\nTous les tests ClaraServ sont passés."
