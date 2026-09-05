#############################################################################
# ClaraServ — Service IRC d’animation en Tcl
# Dépôt : https://github.com/ZarTek-Creole/TCL-ClaraServ
# Licence : CC BY 4.0
#############################################################################

if {[info commands ::ClaraServ::uninstall] ne ""} {
    ::ClaraServ::uninstall
}

namespace eval ::ClaraServ {
    variable CONNECT_ID {}
    variable BOT_ID {}
    variable SCRIPT
    variable config
    variable database {}
    variable commandResponses [dict create]
    variable commandLabels [dict create]
    variable commandNames {}
    # Lifecycle standalone (vwait) — 0 = en cours ; 1 = demandé. Toujours initialiser avant vwait.
    variable shutdown 0
    variable exitCode 0
    variable shuttingDown 0
    variable stopFile {}
    variable pidFile {}
    variable stopFileAfterId {}
    variable runtimeDir {}
    # Limite conservative du texte PRIVMSG/NOTICE (octets UTF-8), DÉDUIT hors préfixe IRC (~512).
    variable ircMessageMaxBytes 400
    # Commandes exclues de !random (contenu sensible historique) — liste code, pas de format DB.
    variable randomExcludeCommands [list !sexy !string !fesses !fessée !fouet]

    set scriptDirectory [file dirname [file normalize [info script]]]
    array set SCRIPT [list \
        name        "ClaraServ Service" \
        version     "1.2.0" \
        author      "ZarTek Creole" \
        url         "https://github.com/ZarTek-Creole/TCL-ClaraServ" \
        needZct     "0.1.0" \
        needIrcs    "0.1.0" \
        dirname     $scriptDirectory \
    ]

    array set config {}
    set config(dbList) [list salon.db]
    set config(requiredKeys) [list \
        uplink_host uplink_ssl uplink_port uplink_password \
        serverinfo_name serverinfo_descr serverinfo_id \
        uplink_useprivmsg uplink_debug service_nick service_user \
        service_host service_gecos service_modes service_channel \
        service_chanmodes service_usermodes admin_password \
        log_command db_lang \
    ]
    set config(optionalKeys) [list serverinfo_id service_chanmodes service_usermodes runtime_dir instance_name]
}

namespace eval ::ClaraServ::FCT {}

proc ::ClaraServ::log {level message} {
    # Journalisation standalone vers stderr (journald sous systemd).
    set prefix [format {[%s]} [string toupper $level]]
    puts stderr "$prefix $message"
}

proc ::ClaraServ::uninstall {} {
    # Rechargement / nettoyage namespace (mode tests ou re-source).
    catch {namespace delete ::ClaraServ}
}

proc ::ClaraServ::FCT::Get:ScriptDir {{directory ""}} {
    variable ::ClaraServ::SCRIPT
    if {$directory eq ""} {
        return [file normalize $SCRIPT(dirname)]
    }
    return [file normalize [file join $SCRIPT(dirname) $directory]]
}

proc ::ClaraServ::FCT::Log:Command {command sender} {
    variable ::ClaraServ::config
    if {$config(log_command) && $command ne ""} {
        ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG \
            [format "<c12>Commande :<c04> %s <c12>par<c04> %s" $command $sender]
    }
}

proc ::ClaraServ::FCT::Check:Config {} {
    variable ::ClaraServ::config

    foreach key $config(requiredKeys) {
        if {![info exists config($key)]} {
            return -code error "Configuration ClaraServ incomplète : config($key) est manquant."
        }
        if {$key ni $config(optionalKeys) && [string trim $config($key)] eq ""} {
            return -code error "Configuration ClaraServ invalide : config($key) ne peut pas être vide."
        }
    }

    foreach key {uplink_ssl uplink_useprivmsg uplink_debug log_command} {
        if {![string is boolean -strict $config($key)]} {
            return -code error "Configuration ClaraServ invalide : config($key) doit être booléen (0 ou 1)."
        }
    }

    if {![string is integer -strict $config(uplink_port)] || $config(uplink_port) < 1 || $config(uplink_port) > 65535} {
        return -code error "Configuration ClaraServ invalide : config(uplink_port) doit être un port TCP compris entre 1 et 65535."
    }

    if {![::ClaraServ::FCT::Channel:IsValid $config(service_channel)]} {
        return -code error "Configuration ClaraServ invalide : config(service_channel) doit être un nom de salon IRC valide."
    }

    if {$config(admin_password) eq "votre-mot-2-pass"} {
        return -code error "Configuration ClaraServ invalide : changez le mot de passe administrateur d’exemple."
    }

    # Rejeter placeholders d’exemple / doc (ne jamais démarrer avec des tokens non substitués).
    set placeholderKeys {
        uplink_host uplink_port uplink_password serverinfo_name serverinfo_id
        service_host admin_password
    }
    foreach key $placeholderKeys {
        set v [string trim $config($key)]
        if {[regexp {^<.*>$} $v] \
                || [string match "IRCD_*" $v] \
                || [string match "CLARASERV_*" $v] \
                || [string match -nocase "*CHANGE_ME*" $v] \
                || [string match -nocase "*mypassword*" $v] \
                || $v in {
                    IRCD_HOST_OR_LOOPBACK IRCD_S2S_TLS_PORT CLARASERV_LINK_PASSWORD
                    CLARASERV_SERVICE_NAME CLARASERV_SERVICE_SID CA_FILE_OR_CERT_POLICY
                }} {
            return -code error "Configuration ClaraServ invalide : config($key) contient encore un placeholder/exemple."
        }
    }

    # SID TS6 Unreal courant : 3 caractères [0-9][0-9A-Z]{2} (si non vide).
    set sid [string trim $config(serverinfo_id)]
    if {$sid ne "" && ![regexp {^[0-9][0-9A-Z]{2}$} $sid]} {
        return -code error {Configuration ClaraServ invalide : config(serverinfo_id) doit être un SID TS6 de la forme [0-9][0-9A-Z]{2}.}
    }

    if {$config(uplink_debug)} {
        ::ClaraServ::log warn "uplink_debug=1 : le trafic S2S (dont PASS) peut être journalisé. Réserver au labo ; désactiver ensuite."
    }
}

proc ::ClaraServ::FCT::Channel:IsValid {channel} {
    return [regexp {^#[^[:space:]\x00-\x1f,:]{1,50}$} $channel]
}

proc ::ClaraServ::FCT::Command:Normalise {command} {
    set command [string trim $command]
    return [string tolower [::ZCT::TXT::remove_accents $command]]
}

# Neutralise contrôles IRC / CR-LF dans un pseudo ou nick avant insertion dans une réponse.
proc ::ClaraServ::FCT::Sanitize:Irc:Text {text} {
    # Supprime C0 + DEL (dont \x02 \x03 \x0f \x16 \x1f, CR, LF) ; conserve le reste UTF-8.
    regsub -all {[\x00-\x1f\x7f]} $text {} text
    return $text
}

# Distance d’édition exactement 1 (substitution, insertion ou suppression).
proc ::ClaraServ::FCT::Is:Edit:Distance:One {a b} {
    set la [string length $a]
    set lb [string length $b]
    set diff [expr {abs($la - $lb)}]
    if {$diff > 1} {
        return 0
    }
    if {$diff == 0} {
        set mismatches 0
        for {set i 0} {$i < $la} {incr i} {
            if {[string index $a $i] ne [string index $b $i]} {
                incr mismatches
                if {$mismatches > 1} {
                    return 0
                }
            }
        }
        return [expr {$mismatches == 1}]
    }
    if {$la > $lb} {
        set longer $a
        set shorter $b
    } else {
        set longer $b
        set shorter $a
    }
    set i 0
    set j 0
    set skipped 0
    set llen [string length $longer]
    set slen [string length $shorter]
    while {$i < $llen && $j < $slen} {
        if {[string index $longer $i] eq [string index $shorter $j]} {
            incr i
            incr j
        } else {
            incr skipped
            if {$skipped > 1} {
                return 0
            }
            incr i
        }
    }
    return 1
}

# Suggestion publique unique (distance 1) parmi animations + meta ; pas d’admin.
proc ::ClaraServ::FCT::Suggest:Public:Command {unknownCommand} {
    set unknown [::ClaraServ::FCT::Command:Normalise $unknownCommand]
    set candidates [::ClaraServ::FCT::DB:CMD:LIST]
    foreach meta {!help !cmds !about !random} {
        if {$meta ni $candidates} {
            lappend candidates $meta
        }
    }
    set matches {}
    foreach candidate $candidates {
        set normalised [::ClaraServ::FCT::Command:Normalise $candidate]
        if {[::ClaraServ::FCT::Is:Edit:Distance:One $unknown $normalised]} {
            lappend matches $candidate
        }
    }
    if {[llength $matches] == 1} {
        return [lindex $matches 0]
    }
    return {}
}

proc ::ClaraServ::FCT::Reply:Unknown:Public {sender command} {
    set suggestion [::ClaraServ::FCT::Suggest:Public:Command $command]
    if {$suggestion ne ""} {
        set message [format \
            "<c12>Commande inconnue. Voulez-vous dire <c07>%s<c12> ?<s>" \
            $suggestion]
    } else {
        set message "<c12>Commande inconnue. Utilisez <c07>!cmds<c12> pour recevoir la liste des commandes.<s>"
    }
    # Notice/PRIVMSG privé à l’auteur — une seule réponse, non bruyante en salon.
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender $message
    return 1
}

proc ::ClaraServ::FCT::Needs:Irc:Style {message} {
    if {[regexp -nocase {<(c[0-9,]{0,5}|/c[0-9,]{0,5}|b|/b|u|/u|i|/i|s)>} $message]} {
        return 1
    }
    return [regexp {[\x02\x03\x0f\x1f\x16]} $message]
}

proc ::ClaraServ::FCT::Ensure:Trailing:Reset:Tag {message} {
    regsub -all {(<s>)+\s*$} $message {} message
    append message "<s>"
    return $message
}

# Troncature UTF-8 par octets sans couper un codepoint ; retire contrôles IRC orphelins en fin.
proc ::ClaraServ::FCT::Truncate:Utf8:Bytes {text maxBytes} {
    if {$maxBytes < 1} {
        return {}
    }
    if {[string bytelength $text] <= $maxBytes} {
        return $text
    }
    set out {}
    set bytes 0
    set length [string length $text]
    for {set i 0} {$i < $length} {incr i} {
        set ch [string index $text $i]
        set cb [string bytelength $ch]
        if {($bytes + $cb) > $maxBytes} {
            break
        }
        append out $ch
        incr bytes $cb
    }
    # Évite une séquence couleur/contrôle tronquée en fin de buffer.
    while {[regexp {[\x02\x03\x0f\x1f\x16]$} $out]} {
        set out [string range $out 0 end-1]
    }
    regsub {\x03[0-9]{0,2}(,[0-9]{0,2})?$} $out {} out
    return $out
}

# Rendu final : apply ZCT + reset unique si style + plafond octets (DÉDUIT 400).
proc ::ClaraServ::FCT::Render:Outgoing {message} {
    variable ::ClaraServ::ircMessageMaxBytes

    set styled [::ClaraServ::FCT::Needs:Irc:Style $message]
    if {$styled} {
        set message [::ClaraServ::FCT::Ensure:Trailing:Reset:Tag $message]
    }
    set out [::ZCT::TXT::visuals::apply $message]
    if {$styled} {
        regsub -all {\x0f+$} $out {} out
        append out "\x0f"
    }

    set maxBytes 400
    if {[info exists ircMessageMaxBytes] && [string is integer -strict $ircMessageMaxBytes] && $ircMessageMaxBytes > 32} {
        set maxBytes $ircMessageMaxBytes
    }
    if {[string bytelength $out] > $maxBytes} {
        set reserve [expr {$styled ? 1 : 0}]
        set out [::ClaraServ::FCT::Truncate:Utf8:Bytes $out [expr {$maxBytes - $reserve}]]
        if {$styled || [regexp {[\x02\x03\x1f\x16]} $out]} {
            regsub -all {\x0f+$} $out {} out
            append out "\x0f"
        }
    }
    return $out
}

proc ::ClaraServ::FCT::Message:Words {message} {
    # Le protocole IRC sépare les arguments sur les espaces. Cette méthode
    # n’interprète jamais le message reçu comme une liste Tcl, ce qui rend
    # inoffensives les accolades non appariées signalées dans l’issue #10.
    return [regexp -all -inline {\S+} $message]
}

proc ::ClaraServ::FCT::DB:INIT {fileNames} {
    set databaseDirectory [::ClaraServ::FCT::Get:ScriptDir db]
    if {![file isdirectory $databaseDirectory]} {
        file mkdir $databaseDirectory
    }

    foreach fileName $fileNames {
        set databaseFile [file join $databaseDirectory $fileName]
        if {![file exists $databaseFile]} {
            set fileHandle [open $databaseFile a]
            close $fileHandle
        }
    }
}

proc ::ClaraServ::FCT::DB:Index {} {
    variable ::ClaraServ::database
    variable ::ClaraServ::commandResponses
    variable ::ClaraServ::commandLabels
    variable ::ClaraServ::commandNames

    set commandResponses [dict create]
    set commandLabels [dict create]
    set commandNames {}

    foreach entry $database {
        if {[llength $entry] != 3 || [llength [lindex $entry 0]] != 1} {
            return -code error "Entrée d’animation invalide : chaque entrée doit contenir {{!commande} {niveau} {texte}}."
        }

        set command [lindex [lindex $entry 0] 0]
        set level [lindex $entry 1]
        set response [lindex $entry 2]
        set normalisedCommand [::ClaraServ::FCT::Command:Normalise $command]

        if {![string match "!*" $command] || [string length $command] < 2} {
            return -code error "Commande d’animation invalide : ‘$command’ doit commencer par !."
        }
        if {$level ni {0 1}} {
            return -code error "Niveau invalide pour ‘$command’ : seules les valeurs 0 et 1 sont autorisées."
        }
        if {[dict exists $commandResponses $normalisedCommand $level]} {
            return -code error "Entrée d’animation dupliquée : ‘$command’ (niveau $level)."
        }

        dict set commandResponses $normalisedCommand $level $response
        if {![dict exists $commandLabels $normalisedCommand]} {
            dict set commandLabels $normalisedCommand $command
            lappend commandNames $command
        }
    }

    set commandNames [lsort -dictionary -unique $commandNames]
}

proc ::ClaraServ::FCT::DB:GET {command level} {
    variable ::ClaraServ::commandResponses
    set normalisedCommand [::ClaraServ::FCT::Command:Normalise $command]
    if {[dict exists $commandResponses $normalisedCommand $level]} {
        return [dict get $commandResponses $normalisedCommand $level]
    }
    return -1
}

proc ::ClaraServ::FCT::DB:CMD:LIST {} {
    variable ::ClaraServ::commandNames
    return $commandNames
}

proc ::ClaraServ::FCT::DB:DATA:EXIST {databaseName data} {
    set databaseFile [file join [::ClaraServ::FCT::Get:ScriptDir db] "${databaseName}.db"]
    if {![file exists $databaseFile]} {
        return -1
    }

    set fileHandle [open $databaseFile r]
    try {
        while {[gets $fileHandle line] >= 0} {
            if {[string equal -nocase $data [string trim $line]]} {
                return 1
            }
        }
    } finally {
        close $fileHandle
    }
    return 0
}

proc ::ClaraServ::FCT::DB:SALON:ADD {channel} {
    if {![::ClaraServ::FCT::Channel:IsValid $channel]} {
        return 0
    }
    if {[::ClaraServ::FCT::DB:DATA:EXIST salon $channel] != 0} {
        return -1
    }

    set databaseFile [file join [::ClaraServ::FCT::Get:ScriptDir db] salon.db]
    set fileHandle [open $databaseFile a]
    try {
        puts $fileHandle $channel
    } finally {
        close $fileHandle
    }
    return 1
}

proc ::ClaraServ::FCT::DB:DATA:REMOVE {databaseName data} {
    set databaseFile [file join [::ClaraServ::FCT::Get:ScriptDir db] "${databaseName}.db"]
    if {![file exists $databaseFile]} {
        return -1
    }

    set retainedLines {}
    set found 0
    set fileHandle [open $databaseFile r]
    try {
        while {[gets $fileHandle line] >= 0} {
            set line [string trim $line]
            if {$line eq ""} {
                continue
            }
            if {[string equal -nocase $data $line]} {
                set found 1
            } else {
                lappend retainedLines $line
            }
        }
    } finally {
        close $fileHandle
    }

    if {!$found} {
        return 0
    }

    # Écriture atomique : aucun fichier tronqué ne peut être laissé si
    # le processus s’arrête entre l’écriture et le renommage.
    set temporaryFile "${databaseFile}.[pid].tmp"
    set fileHandle [open $temporaryFile w]
    try {
        foreach line $retainedLines {
            puts $fileHandle $line
        }
    } finally {
        close $fileHandle
    }
    file rename -force $temporaryFile $databaseFile
    return 1
}

proc ::ClaraServ::FCT::SENT:NOTICE {destination message} {
    variable ::ClaraServ::BOT_ID
    $BOT_ID notice $destination [::ClaraServ::FCT::Render:Outgoing $message]
}

proc ::ClaraServ::FCT::SENT:PRIVMSG {destination message} {
    variable ::ClaraServ::BOT_ID
    $BOT_ID privmsg $destination [::ClaraServ::FCT::Render:Outgoing $message]
}

proc ::ClaraServ::FCT::SENT:MSG:TO:USER {destination message} {
    variable ::ClaraServ::config
    if {$config(uplink_useprivmsg)} {
        ::ClaraServ::FCT::SENT:PRIVMSG $destination $message
    } else {
        ::ClaraServ::FCT::SENT:NOTICE $destination $message
    }
}

proc ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG {message} {
    variable ::ClaraServ::config
    ::ClaraServ::FCT::SENT:PRIVMSG $config(service_channel) $message
}

proc ::ClaraServ::FCT::CMD:SHOW:LIST {destination} {
    set maximumPerLine 8
    set displayWidth 13
    set commandLine {}
    set commandCount 0

    foreach command [::ClaraServ::FCT::DB:CMD:LIST] {
        lappend commandLine "<c07>[string map [list ! !<c06>] [::ZCT::TXT::visuals::espace $command $displayWidth]]<c12>"
        incr commandCount
        if {$commandCount == $maximumPerLine} {
            ::ClaraServ::FCT::SENT:MSG:TO:USER $destination [join $commandLine " | "]
            set commandLine {}
            set commandCount 0
        }
    }

    if {[llength $commandLine] > 0} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $destination [join $commandLine " | "]
    }
}

proc ::ClaraServ::FCT::Dispatch:Command {procedure sender destination command data} {
    if {[catch [list {*}$procedure $sender $destination $command $data] result options]} {
        set errorInfo [dict get $options -errorinfo]
        ::ClaraServ::log error "Échec de la commande $command : $result\n$errorInfo"
        return 0
    }
    return $result
}

proc ::ClaraServ::FCT::Dispatch:Message {sender destination message} {
    set words [::ClaraServ::FCT::Message:Words $message]
    if {[llength $words] == 0} {
        return 0
    }

    set command [::ClaraServ::FCT::Command:Normalise [lindex $words 0]]
    set data [lrange $words 1 end]

    if {[string index $destination 0] ne "#"} {
        set procedure "::ClaraServ::IRC:CMD:PRIV:[string toupper $command]"
        if {[info commands $procedure] eq ""} {
            ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "Commande %s inconnue." $command]
            return [::ClaraServ::IRC:CMD:PRIV:HELP $sender $destination $command $data]
        }
        return [::ClaraServ::FCT::Dispatch:Command $procedure $sender $destination $command $data]
    }

    if {![string match "!*" $command]} {
        return 0
    }

    set commandName [string range $command 1 end]
    set procedure "::ClaraServ::IRC:CMD:PUB:[string toupper $commandName]"
    if {[info commands $procedure] ne ""} {
        return [::ClaraServ::FCT::Dispatch:Command $procedure $sender $destination $command $data]
    }

    if {[::ClaraServ::FCT::DB:GET $command 0] ne "-1"} {
        return [::ClaraServ::FCT::Dispatch:Command ::ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $command $data]
    }
    return [::ClaraServ::FCT::Reply:Unknown:Public $sender $command]
}

proc ::ClaraServ::INIT {} {
    variable SCRIPT
    variable config

    set configFile [file join [::ClaraServ::FCT::Get:ScriptDir] ClaraServ.conf]
    if {![file exists $configFile]} {
        return -code error "Fichier de configuration introuvable : $configFile. Copiez ClaraServ.Example.conf vers ClaraServ.conf et personnalisez-le."
    }

    if {[catch {namespace eval ::ClaraServ [list source $configFile]} errorMessage]} {
        return -code error "Chargement de $configFile impossible : $errorMessage"
    }
    ::ClaraServ::FCT::Check:Config

    set config(FILE_DB) [format "database.%s.db" [string tolower $config(db_lang)]]
    ::ClaraServ::FCT::DB:INIT [concat $config(dbList) [list $config(FILE_DB)]]

    set animationDatabase [file join [::ClaraServ::FCT::Get:ScriptDir db] $config(FILE_DB)]
    if {![file exists $animationDatabase]} {
        return -code error "Base d’animations introuvable : $animationDatabase"
    }
    if {[catch {namespace eval ::ClaraServ [list source $animationDatabase]} errorMessage]} {
        return -code error "Chargement de $animationDatabase impossible : $errorMessage"
    }
    ::ClaraServ::FCT::DB:Index

    ::ClaraServ::log info [format "%s v%s chargé (par %s)." $SCRIPT(name) $SCRIPT(version) $SCRIPT(author)]
}

# Arrêt gracieux standalone : best-effort QUIT/disconnect puis levée de vwait.
# Ne modifie pas le protocole S2S.
# exitCode : 0 = arrêt volontaire ; non-zéro = panne (ex. EOF) pour Restart=on-failure.
proc ::ClaraServ::FCT::Request:Shutdown {{reason "shutdown"} {requestedExitCode 0}} {
    variable ::ClaraServ::CONNECT_ID
    variable ::ClaraServ::shuttingDown
    variable ::ClaraServ::stopFileAfterId
    variable ::ClaraServ::exitCode

    if {[info exists shuttingDown] && $shuttingDown} {
        return
    }
    set shuttingDown 1
    set exitCode $requestedExitCode

    if {[info exists stopFileAfterId] && $stopFileAfterId ne ""} {
        catch {after cancel $stopFileAfterId}
        set stopFileAfterId {}
    }

    ::ClaraServ::log info "Arrêt demandé ($reason), exitCode=$requestedExitCode."
    if {$CONNECT_ID ne "" && [info commands $CONNECT_ID] ne ""} {
        catch {$CONNECT_ID quit "ClaraServ shutting down ($reason)"}
        catch {$CONNECT_ID disconnect}
    }
    set ::ClaraServ::shutdown 1
}

proc ::ClaraServ::FCT::Poll:StopFile {} {
    variable ::ClaraServ::stopFile
    variable ::ClaraServ::stopFileAfterId
    variable ::ClaraServ::shuttingDown

    if {[info exists shuttingDown] && $shuttingDown} {
        set stopFileAfterId {}
        return
    }
    if {[info exists stopFile] && $stopFile ne "" && [file exists $stopFile]} {
        if {[catch {file delete -force $stopFile} err]} {
            ::ClaraServ::log error "Impossible de consommer le stop-file $stopFile : $err"
        }
        ::ClaraServ::FCT::Request:Shutdown stop-file 0
        return
    }
    set stopFileAfterId [after 500 [list ::ClaraServ::FCT::Poll:StopFile]]
}

proc ::ClaraServ::FCT::Resolve:RuntimeDir {} {
    variable ::ClaraServ::SCRIPT
    variable ::ClaraServ::config
    variable ::ClaraServ::runtimeDir

    set runDir [file join $SCRIPT(dirname) run]
    if {[info exists config(runtime_dir)] && [string trim $config(runtime_dir)] ne ""} {
        set candidate [string trim $config(runtime_dir)]
        if {[file pathtype $candidate] eq "relative"} {
            set runDir [file normalize [file join $SCRIPT(dirname) $candidate]]
        } else {
            set runDir [file normalize $candidate]
        }
    }
    # Multi-instance optionnel : sous-répertoire isolé pour PID/stop-file.
    if {[info exists config(instance_name)] && [string trim $config(instance_name)] ne ""} {
        set inst [string trim $config(instance_name)]
        if {![regexp {^[A-Za-z0-9._-]{1,64}$} $inst]} {
            return -code error {Configuration ClaraServ invalide : config(instance_name) doit matcher [A-Za-z0-9._-]{1,64}.}
        }
        set runDir [file join $runDir $inst]
    }
    set runtimeDir $runDir
    return $runDir
}

# Contrôles réservés à l’exécution directe tclsh (pas lorsque sourcé par les tests).
proc ::ClaraServ::FCT::Install:Standalone:Controls {} {
    variable ::ClaraServ::stopFile
    variable ::ClaraServ::pidFile
    variable ::ClaraServ::stopFileAfterId

    set runDir [::ClaraServ::FCT::Resolve:RuntimeDir]
    if {[catch {file mkdir $runDir} err]} {
        ::ClaraServ::log error "Impossible de créer runtime_dir $runDir : $err"
        return -code error "runtime_dir inaccessible : $runDir ($err)"
    }
    set stopFile [file join $runDir claraserv.stop]
    set pidFile [file join $runDir claraserv.pid]
    if {[catch {file delete -force $stopFile} err]} {
        ::ClaraServ::log warn "Nettoyage stop-file résiduel échoué : $err"
    }
    set fh [open $pidFile w]
    try {
        puts $fh [pid]
    } finally {
        close $fh
    }
    set stopFileAfterId {}
    ::ClaraServ::FCT::Poll:StopFile

    if {![catch {package require Tclx}] && [info commands signal] ne ""} {
        if {[catch {signal trap {TERM INT} [list ::ClaraServ::FCT::Request:Shutdown signal 0]} sigErr]} {
            ::ClaraServ::log warn "Trap SIGTERM/SIGINT impossible : $sigErr"
        } else {
            ::ClaraServ::log info "Arrêt par signal (Ctrl+C / SIGTERM) activé."
        }
    } else {
        ::ClaraServ::log info "Pour arrêter ClaraServ proprement, dans un autre terminal : touch $stopFile"
        ::ClaraServ::log info "(Sans le paquet optionnel Tclx, Ctrl+C ou kill n’arrêtent pas toujours de façon propre.)"
    }
}

proc ::ClaraServ::FCT::Create:Service {} {
    variable ::ClaraServ::CONNECT_ID
    variable ::ClaraServ::BOT_ID
    variable ::ClaraServ::config

    set port $config(uplink_port)
    if {$config(uplink_ssl)} {
        set port "+$port"
    }
    set ts6 [expr {$config(serverinfo_id) ne ""}]

    set CONNECT_ID [::IRCServices::connection]
    $CONNECT_ID connect \
        $config(uplink_host) $port $config(uplink_password) $ts6 \
        $config(serverinfo_name) $config(serverinfo_id) $config(serverinfo_descr)

    if {$config(uplink_debug)} {
        $CONNECT_ID config logger 1
        $CONNECT_ID config debug 1
    }

    set BOT_ID [$CONNECT_ID bot]
    $BOT_ID create \
        $config(service_nick) $config(service_user) $config(service_host) \
        $config(service_gecos) $config(service_modes)
    $BOT_ID join $config(service_channel)

    $BOT_ID registerevent EOS {
        [sid] mode ${::ClaraServ::config(service_channel)} ${::ClaraServ::config(service_chanmodes)}
        if {${::ClaraServ::config(service_usermodes)} ne ""} {
            [sid] mode ${::ClaraServ::config(service_channel)} ${::ClaraServ::config(service_usermodes)} ${::ClaraServ::config(service_nick)}
        }

        set channelsFile [file join [::ClaraServ::FCT::Get:ScriptDir db] salon.db]
        set channelsHandle [open $channelsFile r]
        try {
            while {[gets $channelsHandle channel] >= 0} {
                set channel [string trim $channel]
                if {$channel eq "" || ![::ClaraServ::FCT::Channel:IsValid $channel]} {
                    continue
                }
                [bid] join $channel
                if {${::ClaraServ::config(service_usermodes)} ne ""} {
                    [sid] mode $channel ${::ClaraServ::config(service_usermodes)} ${::ClaraServ::config(service_nick)}
                }
            }
        } finally {
            close $channelsHandle
        }
    }

    $BOT_ID registerevent PRIVMSG {
        ::ClaraServ::FCT::Dispatch:Message [who2] [target] [msg]
    }

    # EOF inattendu : quitter avec code non nul pour permettre Restart=on-failure.
    # Pas de reconnect in-process (état UID/bot ambigu). Arrêt volontaire = stop-file (code 0).
    $CONNECT_ID registerevent EOF {
        ::ClaraServ::log warn "Liaison IRC fermée (EOF). Arrêt du processus (superviseur peut redémarrer)."
        ::ClaraServ::FCT::Request:Shutdown eof-unexpected 1
    }
}

proc ::ClaraServ::IRC:CMD:PUB:RANDOM {sender destination command data} {
    variable ::ClaraServ::randomExcludeCommands

    set commands {}
    foreach candidate [::ClaraServ::FCT::DB:CMD:LIST] {
        set normalised [::ClaraServ::FCT::Command:Normalise $candidate]
        set excluded 0
        foreach blocked $randomExcludeCommands {
            if {$normalised eq [::ClaraServ::FCT::Command:Normalise $blocked]} {
                set excluded 1
                break
            }
        }
        if {!$excluded} {
            lappend commands $candidate
        }
    }
    if {[llength $commands] == 0} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $destination "Aucune animation n’est disponible."
        return 0
    }

    set randomCommand [lindex $commands [expr {int(rand() * [llength $commands])}]]
    return [::ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $randomCommand $data]
}

proc ::ClaraServ::IRC:CMD:PUB:DYNAMIC {sender destination command pseudo} {
    set sender [::ClaraServ::FCT::Sanitize:Irc:Text $sender]
    if {[llength $pseudo] == 0} {
        set response [::ClaraServ::FCT::DB:GET $command 0]
        set pseudo ""
    } else {
        set response [::ClaraServ::FCT::DB:GET $command 1]
        set pseudo [::ClaraServ::FCT::Sanitize:Irc:Text [lindex $pseudo 0]]
    }

    if {$response eq "-1"} {
        return 0
    }

    set response [::ZCT::TXT::REPLACE_SUBSTITUTE $response $destination]
    set response [string map [list \
        %pseudo% $pseudo \
        %sender% $sender \
        %destination% $destination \
    ] $response]
    ::ClaraServ::FCT::SENT:PRIVMSG $destination $response
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PUB:CMDS {sender destination command data} {
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Liste des commandes envoyée en privé à %s<c04> :." $sender]
    return [::ClaraServ::IRC:CMD:PRIV:CMDS $sender $destination $command $data]
}

proc ::ClaraServ::IRC:CMD:PRIV:CMDS {sender destination command data} {
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Liste des commandes d’animations<c04> :."
    ::ClaraServ::FCT::CMD:SHOW:LIST $sender
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Autres commandes<c04> :."
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!help <c12>-<c04> Affiche l’aide"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!<s><<c06>commande<s>> \[<c06>pseudonyme<s>\] <c12>-<c04> Exécute une animation"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!random <s>\[<c06>pseudonyme<s>\] <c12>-<c04> Choisit une animation aléatoire"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c12>!about <c12>-<c04> Affiche les informations sur %s" ${::ClaraServ::config(service_nick)}]
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PUB:ABOUT {sender destination command data} {
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Informations de %s envoyées en privé à %s<c04> :." ${::ClaraServ::config(service_nick)} $sender]
    return [::ClaraServ::IRC:CMD:PRIV:ABOUT $sender $destination $command $data]
}

proc ::ClaraServ::IRC:CMD:PRIV:ABOUT {sender destination command data} {
    variable ::ClaraServ::SCRIPT
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c04>.: <c12>À propos de %s<c04> :." $SCRIPT(name)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>Version <c12>:<c06> v%s" $SCRIPT(version)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>Auteur <c12>:<c06> %s" $SCRIPT(author)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>Site web <c12>:<c06> %s" $SCRIPT(url)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>Dépendances <c12>:<c07> ZCT v<c06>%s<c12>,<c07> IRCServices v<c06>%s" $SCRIPT(needZct) $SCRIPT(needIrcs)]
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PUB:HELP {sender destination command data} {
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Aide envoyée en privé à %s<c04> :." $sender]
    return [::ClaraServ::IRC:CMD:PRIV:HELP $sender $destination $command $data]
}

proc ::ClaraServ::IRC:CMD:PRIV:HELP {sender destination command data} {
    variable ::ClaraServ::config
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Commandes en salon<c04> :."
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!help <c07>-<c06> Affiche cette aide"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!cmds <c07>-<c06> Affiche la liste des commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!<s><<c07>commande<s>> \[<c06>pseudonyme<s>\] <c07>-<c06> Exécute une animation"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!random <s>\[<c06>pseudonyme<s>\] <c07>-<c06> Choisit une animation aléatoire"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>!about <c07>-<c06> À propos de %s" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Commandes privées<c04> :."
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>help <c07>-<c06> Affiche cette aide"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>cmds <c07>-<c06> Affiche la liste des commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>about <c07>-<c06> À propos de %s" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>join <s><<c06>#salon<s>> <<c06>mot_de_passe_admin<s>> <c07>-<c06> Ajoute %s au salon" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>part <s><<c06>#salon<s>> <<c06>mot_de_passe_admin<s>> <c07>-<c06> Retire %s du salon" $config(service_nick)]
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PRIV:JOIN {sender destination command data} {
    variable ::ClaraServ::BOT_ID
    variable ::ClaraServ::config

    set channel [lindex $data 0]
    set password [lindex $data 1]
    if {![::ClaraServ::FCT::Channel:IsValid $channel] || $password eq ""} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "Syntaxe : /msg %s join <#salon> <mot_de_passe_admin>" $config(service_nick)]
        return 0
    }
    if {![string equal $password $config(admin_password)]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Accès refusé."
        ::ClaraServ::FCT::Log:Command "join refusé pour $channel" $sender
        return 0
    }

    if {[::ClaraServ::FCT::DB:SALON:ADD $channel] != 1} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "%s est déjà enregistré ou invalide." $channel]
        return 0
    }

    $BOT_ID join $channel
    if {$config(service_usermodes) ne ""} {
        $BOT_ID mode $channel $config(service_usermodes) $config(service_nick)
    }
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "Le service a rejoint %s." $channel]
    ::ClaraServ::FCT::Log:Command "join $channel" $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PRIV:PART {sender destination command data} {
    variable ::ClaraServ::BOT_ID
    variable ::ClaraServ::config

    set channel [lindex $data 0]
    set password [lindex $data 1]
    if {![::ClaraServ::FCT::Channel:IsValid $channel] || $password eq ""} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "Syntaxe : /msg %s part <#salon> <mot_de_passe_admin>" $config(service_nick)]
        return 0
    }
    if {![string equal $password $config(admin_password)]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Accès refusé."
        ::ClaraServ::FCT::Log:Command "part refusé pour $channel" $sender
        return 0
    }
    if {[string equal -nocase $config(service_channel) $channel]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "%s est le salon de journalisation et ne peut pas être retiré." $channel]
        return 0
    }
    if {[::ClaraServ::FCT::DB:DATA:REMOVE salon $channel] != 1} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "%s n’est pas enregistré." $channel]
        return 0
    }

    $BOT_ID part $channel
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "Le service a quitté %s." $channel]
    ::ClaraServ::FCT::Log:Command "part $channel" $sender
    return 1
}

set zctFile [file join [::ClaraServ::FCT::Get:ScriptDir] modules TCL-ZCT ZCT.tcl]
if {![file exists $zctFile]} {
    return -code error "Dépendance ZCT introuvable : $zctFile"
}
if {[catch {source $zctFile} errorMessage]} {
    return -code error "Chargement de ZCT impossible : $errorMessage"
}
if {[catch {package require ZCT $::ClaraServ::SCRIPT(needZct)} errorMessage]} {
    return -code error "ZCT $::ClaraServ::SCRIPT(needZct) est requis : $errorMessage"
}

set ircServicesFile [file join [::ClaraServ::FCT::Get:ScriptDir] modules TCL-PKG-IRCServices ircservices.tcl]
if {![file exists $ircServicesFile]} {
    return -code error "Dépendance IRCServices introuvable : $ircServicesFile"
}
if {[catch {source $ircServicesFile} errorMessage]} {
    return -code error "Chargement d’IRCServices impossible : $errorMessage"
}
if {[catch {package require IRCServices $::ClaraServ::SCRIPT(needIrcs)} errorMessage]} {
    return -code error "IRCServices $::ClaraServ::SCRIPT(needIrcs) est requis : $errorMessage"
}

if {![info exists ::ClaraServ::disableAutoStart] || !$::ClaraServ::disableAutoStart} {
    if {[catch {
        ::ClaraServ::INIT
        ::ClaraServ::FCT::Create:Service
    } errorMessage options]} {
        ::ClaraServ::log error "$errorMessage\n[dict get $options -errorinfo]"
        return -code error $errorMessage
    }
}

package provide ClaraServ $::ClaraServ::SCRIPT(version)

# Lors d’une exécution directe par tclsh, Tcl doit rester dans sa boucle
# événementielle pour recevoir les lignes IRC. Quand ce fichier est sourcé
# (par les tests), l’hôte possède déjà sa propre boucle.
if {[info exists ::argv0] && [file normalize [info script]] eq [file normalize $::argv0]} {
    set ::ClaraServ::shutdown 0
    set ::ClaraServ::exitCode 0
    set ::ClaraServ::shuttingDown 0
    if {[catch {::ClaraServ::FCT::Install:Standalone:Controls} ctrlErr]} {
        ::ClaraServ::log error $ctrlErr
        exit 1
    }
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
}
