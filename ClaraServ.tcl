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
    set config(optionalKeys) [list serverinfo_id service_chanmodes service_usermodes]
}

namespace eval ::ClaraServ::FCT {}

proc ::ClaraServ::log {level message} {
    set prefix [format {[%s]} [string toupper $level]]
    if {[info commands ::putlog] ne ""} {
        putlog "$prefix $message"
    } else {
        puts stderr "$prefix $message"
    }
}

proc ::ClaraServ::uninstall {} {
    if {[info commands ::binds] ne "" && [info commands ::unbind] ne ""} {
        set namespaceName [namespace current]
        foreach binding [lsearch -inline -all -regexp [binds *${namespaceName}*] " ${namespaceName}"] {
            catch {unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]}
        }
    }
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
}

proc ::ClaraServ::FCT::Channel:IsValid {channel} {
    return [regexp {^#[^[:space:]\x00-\x1f,:]{1,50}$} $channel]
}

proc ::ClaraServ::FCT::Command:Normalise {command} {
    set command [string trim $command]
    return [string tolower [::ZCT::TXT::remove_accents $command]]
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
    $BOT_ID notice $destination [::ZCT::TXT::visuals::apply $message]
}

proc ::ClaraServ::FCT::SENT:PRIVMSG {destination message} {
    variable ::ClaraServ::BOT_ID
    $BOT_ID privmsg $destination [::ZCT::TXT::visuals::apply $message]
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
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination "<c>"
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
    return 0
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
}

proc ::ClaraServ::IRC:CMD:PUB:RANDOM {sender destination command data} {
    set commands [::ClaraServ::FCT::DB:CMD:LIST]
    if {[llength $commands] == 0} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $destination "Aucune animation n’est disponible."
        return 0
    }

    set randomCommand [lindex $commands [expr {int(rand() * [llength $commands])}]]
    return [::ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $randomCommand $data]
}

proc ::ClaraServ::IRC:CMD:PUB:DYNAMIC {sender destination command pseudo} {
    if {[llength $pseudo] == 0} {
        set response [::ClaraServ::FCT::DB:GET $command 0]
        set pseudo ""
    } else {
        set response [::ClaraServ::FCT::DB:GET $command 1]
        set pseudo [lindex $pseudo 0]
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
# (par Eggdrop ou par les tests), l’hôte possède déjà sa propre boucle.
if {[file normalize [info script]] eq [file normalize $::argv0]} {
    vwait ::ClaraServ::shutdown
}
