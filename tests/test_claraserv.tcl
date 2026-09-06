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

set savedHost $::ClaraServ::config(uplink_host)
set ::ClaraServ::config(uplink_host) IRCD_HOST_OR_LOOPBACK
assertTrue {[catch {::ClaraServ::FCT::Check:Config}]} "Un placeholder uplink_host est rejeté"
set ::ClaraServ::config(uplink_host) $savedHost
set ::ClaraServ::config(serverinfo_id) AB1
assertTrue {[catch {::ClaraServ::FCT::Check:Config}]} "Un SID de forme invalide est rejeté"
set ::ClaraServ::config(serverinfo_id) 00C
assertEqual "" [::ClaraServ::FCT::Check:Config] "Configuration valide après restauration SID"

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

# Arrêt gracieux hors réseau
set ::ClaraServ::CONNECT_ID {}
set ::ClaraServ::BOT_ID {}
set ::ClaraServ::shutdown 0
set ::ClaraServ::exitCode 0
set ::ClaraServ::shuttingDown 0
::ClaraServ::FCT::Request:Shutdown test-harness 0
assertEqual "1" $::ClaraServ::shutdown "Request:Shutdown positionne ::ClaraServ::shutdown"
assertEqual "0" $::ClaraServ::exitCode "Arrêt volontaire exitCode=0"
assertEqual "1" $::ClaraServ::shuttingDown "shuttingDown armé"
::ClaraServ::FCT::Request:Shutdown second-call 99
assertEqual "0" $::ClaraServ::exitCode "Second Request:Shutdown est no-op (idempotent)"

# Stop-file : Poll:StopFile détecte immédiatement un fichier présent
set stopDirectory [file normalize [file join $testDirectory tmp-stop-[pid]]]
file mkdir [file join $stopDirectory run]
set savedDir $::ClaraServ::SCRIPT(dirname)
set ::ClaraServ::SCRIPT(dirname) $stopDirectory
set ::ClaraServ::config(runtime_dir) ""
set ::ClaraServ::stopFile [file join $stopDirectory run claraserv.stop]
set ::ClaraServ::shutdown 0
set ::ClaraServ::exitCode 0
set ::ClaraServ::shuttingDown 0
set ::ClaraServ::stopFileAfterId {}
close [open $::ClaraServ::stopFile w]
::ClaraServ::FCT::Poll:StopFile
assertEqual "1" $::ClaraServ::shutdown "Le stop-file déclenche Request:Shutdown"
assertTrue {![file exists $::ClaraServ::stopFile]} "Le stop-file est consommé"

# Resolve:RuntimeDir relatif
set ::ClaraServ::config(runtime_dir) "var/run-cs"
set resolved [::ClaraServ::FCT::Resolve:RuntimeDir]
assertTrue {[string match *var/run-cs $resolved]} "runtime_dir relatif résolu sous la racine script"
assertEqual [file normalize [file join $stopDirectory var/run-cs]] $resolved "runtime_dir normalisé"

# instance_name isole le runtime
set ::ClaraServ::config(runtime_dir) [file join $stopDirectory run-inst]
set ::ClaraServ::config(instance_name) lab-a
set resolvedInst [::ClaraServ::FCT::Resolve:RuntimeDir]
assertEqual [file normalize [file join $stopDirectory run-inst lab-a]] $resolvedInst "instance_name sous runtime_dir"
set ::ClaraServ::config(instance_name) "bad name"
assertTrue {[catch {::ClaraServ::FCT::Resolve:RuntimeDir}]} "instance_name invalide rejeté"
set ::ClaraServ::config(instance_name) lab-a

# Logging standalone : aucune primitive hôte bot requise
assertTrue {[info commands ::putlog] eq ""} "Environnement de test sans commande putlog"
assertTrue {[info commands ::putserv] eq ""} "Environnement de test sans commande putserv"
assertTrue {[info commands ::puthelp] eq ""} "Environnement de test sans commande puthelp"
assertTrue {[info commands ::bind] eq ""} "Environnement de test sans commande bind"
::ClaraServ::log info "message-test-log-standalone"
assertTrue {[info commands ::ClaraServ::log] ne ""} "Abstraction ::ClaraServ::log présente"
assertTrue {[catch {::ClaraServ::log warn "test-warn-standalone"}] == 0} "log standalone fonctionne sous tclsh"

# Resolve:RuntimeDir absolu
array unset ::ClaraServ::config instance_name
set absRun [file normalize [file join $stopDirectory abs-run]]
set ::ClaraServ::config(runtime_dir) $absRun
set resolvedAbs [::ClaraServ::FCT::Resolve:RuntimeDir]
assertEqual $absRun $resolvedAbs "runtime_dir absolu conservé normalisé"

# Install:Standalone:Controls consomme un stop résiduel et écrit le PID (hors réseau)
set ::ClaraServ::config(runtime_dir) [file join $stopDirectory run-ctrl]
set ::ClaraServ::shutdown 0
set ::ClaraServ::exitCode 0
set ::ClaraServ::shuttingDown 0
file mkdir $::ClaraServ::config(runtime_dir)
set residual [file join $::ClaraServ::config(runtime_dir) claraserv.stop]
close [open $residual w]
::ClaraServ::FCT::Install:Standalone:Controls
assertTrue {![file exists $residual]} "Install nettoie un stop-file résiduel"
assertTrue {[file exists $::ClaraServ::pidFile]} "Install écrit le PID file"
assertTrue {$::ClaraServ::stopFileAfterId ne ""} "Poll after programmé"
::ClaraServ::FCT::Request:Shutdown cancel-poll-test 0
assertEqual "" $::ClaraServ::stopFileAfterId "Shutdown annule le poll after"
catch {file delete -force $::ClaraServ::pidFile}

# EOF contract helper: exitCode non nul
set ::ClaraServ::shutdown 0
set ::ClaraServ::exitCode 0
set ::ClaraServ::shuttingDown 0
::ClaraServ::FCT::Request:Shutdown eof-unexpected 1
assertEqual "1" $::ClaraServ::exitCode "EOF inattendu → exitCode=1 pour Restart=on-failure"

# Pré-vwait : si shuttingDown déjà vrai, le bloc standalone doit sauter vwait
# (contract : ne pas appeler vwait quand shutdown déjà posé — testé ici via garde)
assertEqual "1" $::ClaraServ::shuttingDown "shuttingDown reste armé pour garde pré-vwait"
assertTrue {!$::ClaraServ::shuttingDown || $::ClaraServ::shutdown == 1} "Pré-vwait : shutdown cohérent avec shuttingDown"

# Mode normal (source avec disableAutoStart) : aucune auto-connexion
assertEqual "" $::ClaraServ::CONNECT_ID "disableAutoStart → CONNECT_ID vide (pas d’auto-connect)"
assertTrue {[info commands ::ClaraServ::FCT::Create:Service] ne ""} "Create:Service existe toujours (prod inchangé)"

# Harness local-process : refus sans marqueurs d’environnement (sous-processus)
set harnessPath [file join $projectDirectory tests harness_local_process.tcl]
set refuseCode [catch {
    exec env -u CLARASERV_TEST_LOCAL_PROCESS -u CLARASERV_TEST_RUNTIME_DIR \
        tclsh $harnessPath 2>@1
} refuseOut]
assertTrue {$refuseCode != 0} "Harness refuse sans CLARASERV_TEST_LOCAL_PROCESS"
assertTrue {[string match *refus* $refuseOut] || [string match *CLARASERV_TEST_LOCAL_PROCESS* $refuseOut]} \
    "Message de refus harness explicite"

set refuseCode2 [catch {
    exec env CLARASERV_TEST_LOCAL_PROCESS=1 \
        -u CLARASERV_TEST_RUNTIME_DIR \
        tclsh $harnessPath 2>@1
} refuseOut2]
assertTrue {$refuseCode2 != 0} "Harness refuse sans CLARASERV_TEST_RUNTIME_DIR"

# --- UX commandes / rendu IRC / sanitize / longueur ---
proc escapeIrcControls {s} {
    string map [list \x03 <C> \x02 <B> \x0f <R> \x1f <U> \x16 <I> \r <CR> \n <LF>] $s
}

set ::ClaraServ::SCRIPT(dirname) $savedDir
array unset ::ClaraServ::config runtime_dir
file delete -force $stopDirectory

# Recharger l’index FR courant (après éventuels ajouts DB).
set ::ClaraServ::database {}
namespace eval ::ClaraServ [list source [file join $projectDirectory db database.fr.db]]
::ClaraServ::FCT::DB:Index
::ClaraServ::FCT::DB:Load:Enrichment:Files
set ::ClaraServ::rateLimitCooldown 0
array unset ::ClaraServ::rateLimit
set ::ClaraServ::failRate 0
set ::ClaraServ::randForceIndex -1
set ::ClaraServ::randForceFail {}

set ::TestBot::messages {}
set ::ClaraServ::BOT_ID ::TestBot
set ::ClaraServ::config(uplink_useprivmsg) 1
set ::ClaraServ::config(log_command) 0
set ::ClaraServ::config(service_nick) ClaraServ
set ::ClaraServ::config(admin_password) test-admin-pass-for-unit
set ::ClaraServ::config(FILE_DB) database.fr.db

# Texte sans préfixe ! → aucune réponse
set ::TestBot::messages {}
assertEqual "0" [::ClaraServ::FCT::Dispatch:Message Alice #lounge "bonjour tout le monde"] \
    "Sans préfixe ! : aucune commande"
assertEqual "0" [llength $::TestBot::messages] "Sans préfixe ! : aucun message émis"

# !cmdss → suggestion unique !cmds (privé à l’auteur)
# Note: !cms est ambigu (!mms et !cmds, distance 1) → pas de suggestion (règle D2).
set ::TestBot::messages {}
assertEqual "1" [::ClaraServ::FCT::Dispatch:Message Alice #lounge "!cmdss"] \
    "Commande inconnue !cmdss traitée"
assertEqual "1" [llength $::TestBot::messages] "Une seule réponse pour !cmdss"
set cmsMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string match "*!cmds*" $cmsMsg]} "!cmdss suggère !cmds"
assertTrue {[string match "*Voulez-vous dire*" $cmsMsg]} "Formulation suggestion présente"
assertTrue {[regexp {\x0f$} $cmsMsg]} "Suggestion stylée se termine par reset"

# !cms ambigu → message générique (pas de suggestion)
set ::TestBot::messages {}
::ClaraServ::FCT::Dispatch:Message Alice #lounge "!cms"
set ambMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string match "*!cmds*" $ambMsg]} "!cms ambigu pointe vers !cmds générique"
assertTrue {![string match "*Voulez-vous dire*" $ambMsg]} "!cms ambigu : pas de suggestion unique"

# Inconnue sans voisin distance 1
set ::TestBot::messages {}
::ClaraServ::FCT::Dispatch:Message Alice #lounge "!zzzznotacommand"
set unkMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string match "*!cmds*" $unkMsg]} "Inconnue sans suggestion pointe vers !cmds"
assertTrue {![string match "*Voulez-vous dire*" $unkMsg]} "Pas de suggestion ambiguë/absente"

# Sanitize nick
assertEqual "NickNormal" [::ClaraServ::FCT::Sanitize:Irc:Text "NickNormal"] "Pseudo normal inchangé"
assertEqual "Evil" [::ClaraServ::FCT::Sanitize:Irc:Text "Ev\x02il"] "Gras retiré du pseudo"
assertEqual "Evil" [::ClaraServ::FCT::Sanitize:Irc:Text "Ev\x03il"] "Couleur retirée du pseudo"
assertEqual "Evil" [::ClaraServ::FCT::Sanitize:Irc:Text "Ev\x0fil"] "Reset retiré du pseudo"
assertEqual "EvilNick" [::ClaraServ::FCT::Sanitize:Irc:Text "Evil\r\nNick"] "CR/LF retirés du pseudo"

set ::TestBot::messages {}
::ClaraServ::FCT::Dispatch:Message "Sen\x02der" #lounge "!gaufre Tar\x03get"
set dynMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first "Sender" $dynMsg] >= 0} "Sender sanitisé sans gras injecté"
assertTrue {[string first "Target" $dynMsg] >= 0} "Target sanitisé sans couleur injectée"
assertTrue {[regexp {\x0f$} $dynMsg]} "Animation stylée se termine par reset"

# Reset sur help / about / cmds
set ::TestBot::messages {}
::ClaraServ::IRC:CMD:PUB:HELP Alice #lounge !help {}
set helpLast [lindex [lindex $::TestBot::messages end] 2]
assertTrue {[regexp {\x0f$} $helpLast]} "help : dernier message avec reset"

set ::TestBot::messages {}
::ClaraServ::IRC:CMD:PRIV:ABOUT Alice #lounge about {}
set aboutLast [lindex [lindex $::TestBot::messages end] 2]
assertTrue {[regexp {\x0f$} $aboutLast]} "about : dernier message avec reset"

set ::TestBot::messages {}
::ClaraServ::IRC:CMD:PRIV:CMDS Alice #lounge cmds {}
set cmdsLast [lindex [lindex $::TestBot::messages end] 2]
assertTrue {[regexp {\x0f$} $cmdsLast]} "cmds : dernier message avec reset"
assertTrue {![regexp {\x03$} $cmdsLast]} "cmds : ne se termine plus par couleur vide seule"

# Render:Outgoing reset unique
set rendered [::ClaraServ::FCT::Render:Outgoing "<c07>x<c12>y"]
assertTrue {[regexp {\x0f$} $rendered]} "Render ajoute reset final"
assertTrue {![regexp {\x0f\x0f$} $rendered]} "Pas de double reset final"
assertEqual [escapeIrcControls $rendered] "<C>07x<C>12y<R>" "Représentation échappée attendue"

# Troncature message long + reset
set ::ClaraServ::ircMessageMaxBytes 40
set longBody "<c12>[string repeat a 80]<s>"
set trunc [::ClaraServ::FCT::Render:Outgoing $longBody]
assertTrue {[string bytelength $trunc] <= 40} "Message long borné à ircMessageMaxBytes"
assertTrue {[regexp {\x0f$} $trunc]} "Message long tronqué se termine par reset"
set ::ClaraServ::ircMessageMaxBytes 400

# UTF-8 : ne pas couper un codepoint (é = 2 octets)
set ::ClaraServ::ircMessageMaxBytes 5
set utfOut [::ClaraServ::FCT::Truncate:Utf8:Bytes "éééé" 3]
assertTrue {[string is true -strict [expr {[string bytelength $utfOut] <= 3}]]} "Troncature UTF-8 respecte les octets"
assertTrue {[string length $utfOut] <= 1} "Pas de demi-caractère UTF-8"
set ::ClaraServ::ircMessageMaxBytes 400

# !random exclut le contenu sensible listé
assertTrue {[lsearch -exact $::ClaraServ::randomExcludeCommands !sexy] >= 0} "Liste d’exclusion random définie"
set pool {}
foreach c [::ClaraServ::FCT::DB:CMD:LIST] {
    set cn [::ClaraServ::FCT::Command:Normalise $c]
    set ex 0
    foreach b $::ClaraServ::randomExcludeCommands {
        if {$cn eq [::ClaraServ::FCT::Command:Normalise $b]} { set ex 1; break }
    }
    if {!$ex} { lappend pool $c }
}
assertTrue {[lsearch -exact $pool !sexy] < 0} "Pool random sans !sexy"
assertTrue {[llength $pool] < [llength [::ClaraServ::FCT::DB:CMD:LIST]]} "Pool random plus petit que la base"

# Nouvelles commandes FR (échantillon) : niveaux 0/1 + <s> + bold pair
foreach newCmd {!salut !bienvenue !bravo !courage !chance !sourire !applaudir !bouquet !jus !musique !amitié !bonnejournée !bonnesoirée !bonnenuit !tope !heureux !cool !paix} {
    set r0 [::ClaraServ::FCT::DB:GET $newCmd 0]
    set r1 [::ClaraServ::FCT::DB:GET $newCmd 1]
    assertTrue {$r0 ne "-1"} "Nouvelle commande $newCmd niveau 0"
    assertTrue {$r1 ne "-1"} "Nouvelle commande $newCmd niveau 1"
    assertTrue {[string match "*<s>" $r0] || [string match "*<s>*" $r0]} "$newCmd/0 contient reset tag"
    assertTrue {[regexp {<s>\s*$} $r0]} "$newCmd/0 finit par <s>"
    assertTrue {[regexp {<s>\s*$} $r1]} "$newCmd/1 finit par <s>"
    set b0 [regexp -all {<b>|</b>} $r0]
    set b1 [regexp -all {<b>|</b>} $r1]
    assertTrue {($b0 % 2) == 0} "$newCmd/0 gras apparié"
    assertTrue {($b1 % 2) == 0} "$newCmd/1 gras apparié"
}

# Validateur DB : fixture invalide détectée
set validator [file join $projectDirectory tools validate-animations-db.tcl]
assertTrue {[file isfile $validator]} "Validateur DB présent"
set badDir [file join $testDirectory tmp-bad-db-[pid]]
file mkdir $badDir
set badDb [file join $badDir bad.db]
set bf [open $badDb w]
puts $bf "variable database \{"
puts $bf "\t\{\{!bad\} \{0\} \{<c07>sans reset et <b>gras impair\}\}"
puts $bf "\}"
close $bf
set valOut ""
set valCode [catch {exec tclsh $validator $badDb 2>@1} valOut]
assertTrue {$valCode != 0} "Validateur échoue sur fixture invalide"
assertTrue {[string match "*FAIL*" $valOut] || [string match "*fail*" [string tolower $valOut]]} \
    "Validateur signale FAIL sur fixture"
file delete -force $badDir

# CONNECT_ID toujours vide (pas de réseau dans ces tests)
assertEqual "" $::ClaraServ::CONNECT_ID "Toujours pas d’auto-connect après tests UX"

# --- v1.3 alias / multi-mots / variants / fail / flood / reload ---
assertEqual "!kiss" [::ClaraServ::FCT::DB:ResolveAlias !bisous] "Alias !bisous → !kiss"
assertEqual "!kiss" [::ClaraServ::FCT::DB:ResolveAlias !BISOUS] "Alias normalisation casse"
assertEqual "!pelle" [::ClaraServ::FCT::DB:ResolveAlias !pelle] "!pelle reste canonique"
assertEqual "!zzzz" [::ClaraServ::FCT::DB:ResolveAlias !zzzz] "Alias inexistant inchangé"

set ::TestBot::messages {}
assertEqual "1" [::ClaraServ::FCT::Dispatch:Message Alice #lounge "!bisous Bob"] "Alias !bisous exécuté"
set aliasMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first "Alice" $aliasMsg] >= 0} "Alias : sender présent"
assertTrue {[string first "Bob" $aliasMsg] >= 0} "Alias : cible présente"

assertEqual "Ami" [::ClaraServ::FCT::Parse:Target "Ami"] "ParseTarget mono"
assertEqual "Jean Pierre" [::ClaraServ::FCT::Parse:Target "Jean Pierre"] "ParseTarget multi"
assertEqual "" [::ClaraServ::FCT::Parse:Target "   "] "ParseTarget espaces"
assertEqual "rouge" [::ClaraServ::FCT::Parse:Target "\x03rouge"] "ParseTarget strip couleur"
assertEqual "Ami Pierre" [::ClaraServ::FCT::Parse:Target "Ami\nPierre"] "ParseTarget CR/LF→espace"

set ::TestBot::messages {}
::ClaraServ::FCT::Dispatch:Message Alice #lounge "!kiss Jean Pierre"
set multiMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first "Jean Pierre" $multiMsg] >= 0} "Cible multi-mots dans la réponse"

set vars [::ClaraServ::FCT::DB:GetVariants !kiss 0]
assertTrue {[llength $vars] >= 1} "Variantes !kiss/0 non vides"
set ::ClaraServ::randForceIndex 0
assertEqual [lindex $vars 0] [::ClaraServ::FCT::DB:ChooseVariant $vars] "ChooseVariant index forcé"
set ::ClaraServ::randForceIndex -1

set ::ClaraServ::failRate 0
assertEqual "0" [::ClaraServ::FCT::DB:ShouldFail !kiss 0] "failrate=0 → pas de fail"
set ::ClaraServ::failRate 50
set ::ClaraServ::randForceFail 0
assertEqual "0" [::ClaraServ::FCT::DB:ShouldFail !kiss 0] "fail forcé 0"
set ::ClaraServ::randForceFail 1
assertEqual "1" [::ClaraServ::FCT::DB:ShouldFail !kiss 0] "fail forcé 1"
set ::ClaraServ::randForceFail {}
set ::ClaraServ::failRate 0

set ::ClaraServ::rateLimitCooldown 2
array unset ::ClaraServ::rateLimit
assertEqual "1" [::ClaraServ::FCT::RateLimit:Allowed #t Alice] "flood 1er OK"
assertEqual "0" [::ClaraServ::FCT::RateLimit:Allowed #t Alice] "flood 2e limité"
assertEqual "1" [::ClaraServ::FCT::RateLimit:Allowed #t Alice 1] "flood bypass"
set ::ClaraServ::rateLimitCooldown 0
array unset ::ClaraServ::rateLimit

assertTrue {[::ClaraServ::FCT::DB:GET !bonapp 0] ne "-1"} "Nouvelle cmd !bonapp"
assertTrue {[::ClaraServ::FCT::DB:GET !clin 1] ne "-1"} "Nouvelle cmd !clin"
assertTrue {[::ClaraServ::FCT::DB:GET !lasagne 0] ne "-1"} "Nouvelle cmd !lasagne"

set ::TestBot::messages {}
assertEqual "1" [::ClaraServ::IRC:CMD:PRIV:RELOAD Alice - reload [list test-admin-pass-for-unit]] \
    "reload admin OK"
assertTrue {[string match "*Reload*" [lindex [lindex $::TestBot::messages 0] 2]]} "reload message succès"

set ::TestBot::messages {}
assertEqual "0" [::ClaraServ::IRC:CMD:PRIV:RELOAD Alice - reload [list mauvais]] "reload mauvais mdp"
assertTrue {[string match "*refus*" [string tolower [lindex [lindex $::TestBot::messages 0] 2]]]} "reload refus"

set renderedKw [::ClaraServ::FCT::Render:Template "kw=%keyword% s=%sender%" Alice Bob kiss #chan]
assertEqual "kw=kiss s=Alice" $renderedKw "RenderTemplate %keyword%"

# !random ne doit pas être tué par un double rate-limit
set ::ClaraServ::rateLimitCooldown 2
array unset ::ClaraServ::rateLimit
set ::TestBot::messages {}
assertEqual "1" [::ClaraServ::IRC:CMD:PUB:RANDOM Alice #lounge !random {}] \
    "!random produit une animation (pas de double cooldown)"
assertTrue {[llength $::TestBot::messages] >= 1} "!random a émis au moins un PRIVMSG"
set ::ClaraServ::rateLimitCooldown 0
array unset ::ClaraServ::rateLimit
set ::TestBot::messages {}
assertEqual "1" [::ClaraServ::IRC:CMD:PUB:RANDOM Alice #lounge !random [list ClaraServ]] \
    "!random avec cible"
assertTrue {[llength $::TestBot::messages] >= 1} "!random+cible a émis un message"
set randTargetMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first "ClaraServ" $randTargetMsg] >= 0} "!random+cible insère la cible"
set ::ClaraServ::rateLimitCooldown 0
array unset ::ClaraServ::rateLimit

# Nickmap UID → nick (affichage !cmds / logs / %sender%)
::ClaraServ::FCT::Nickmap:Set 001NWME3E me
assertEqual "me" [::ClaraServ::FCT::Display:Nick 001NWME3E] "UID résolu en nick"
assertEqual "me" [::ClaraServ::FCT::Display:Nick me] "Nick inchangé"
assertTrue {[::ClaraServ::FCT::Looks:Like:Uid 001NWME3E]} "Détection UID TS6"
assertTrue {![::ClaraServ::FCT::Looks:Like:Uid me]} "Nick n’est pas un UID"

set ::ClaraServ::config(log_command) 1
set ::ClaraServ::config(service_channel) #services
set ::TestBot::messages {}
::ClaraServ::FCT::Log:Command !cmds 001NWME3E
set logMsg [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first "me" $logMsg] >= 0} "Log commande affiche le nick"
assertTrue {[string first "001NWME3E" $logMsg] < 0} "Log commande n’affiche pas l’UID"
set ::ClaraServ::config(log_command) 0

set ::TestBot::messages {}
::ClaraServ::IRC:CMD:PUB:CMDS 001NWME3E #lounge !cmds {}
set announce [lindex [lindex $::TestBot::messages 0] 2]
assertTrue {[string first "me" $announce] >= 0} "!cmds annonce le nick pas l’UID"

set ::TestBot::messages {}
::ClaraServ::IRC:CMD:PRIV:ALIAS Alice - alias {}
assertTrue {[llength $::TestBot::messages] >= 2} "!alias / alias liste au moins en-tête + lignes"
set aliasBlob [join $::TestBot::messages " "]
assertTrue {[string match "*!bisous*" $aliasBlob] || [string match "*bisous*" $aliasBlob]} \
    "Liste alias contient bisous"

if {$failures > 0} {
    puts stderr "\n$failures échec(s) de test."
    exit 1
}
puts "\nTous les tests ClaraServ sont passés."
