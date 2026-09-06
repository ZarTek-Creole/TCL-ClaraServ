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

    # Enrichissement vNext — fichiers données (parser non-exécutable, pas source).
    variable aliasesDict [dict create]
    variable variantsDict [dict create]
    variable failsDict [dict create]
    # failrate : pourcentage 0–100 ; 0 = désactivé (défaut).
    variable failRate 0
    # Anti-flood salon+sender (secondes) ; 0 = désactivé.
    variable rateLimitCooldown 2
    variable rateLimit
    array set rateLimit {}
    # Hooks tests : index forcé pour ChooseVariant ; -1 = aléatoire.
    variable randForceIndex -1
    # Hooks tests : "" = aléatoire ; 0/1 force ShouldFail.
    variable randForceFail {}
    # Carte UID TS6 ↔ nick (who2 peut rester un UID si le burst n’a pas peuplé IRCServices).
    variable nickByUid
    array set nickByUid {}
    variable uidByNick
    array set uidByNick {}
    # Ops @ par salon (suivi MODE +o/-o) — clés « CHANNEL\0UID ».
    variable chanOps
    array set chanOps {}
    # Flags contenu par salon : channel → dict adult/vulgar 0|1
    variable salonFlags [dict create]
    # Hook tests : chemin forcé pour salon_flags.db ("" = défaut db/).
    variable salonFlagsPathOverride ""

    set scriptDirectory [file dirname [file normalize [info script]]]
    array set SCRIPT [list \
        name        "ClaraServ Service" \
        version     "1.4.1" \
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
    set config(optionalKeys) [list serverinfo_id service_chanmodes service_usermodes \
        runtime_dir instance_name failrate rate_limit_cooldown \
        content_adult_global content_vulgar_global]
    # Défauts gates contenu (surchargés par ClaraServ.conf si présents).
    set config(content_adult_global) 0
    set config(content_vulgar_global) 0
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
        set shown [::ClaraServ::FCT::Display:Nick $sender]
        ::ClaraServ::FCT::SENT:MSG:TO:CHAN:LOG \
            [format "<c12>Commande :<c04> %s <c12>par<c04> %s" $command $shown]
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

    foreach key {uplink_ssl uplink_useprivmsg uplink_debug log_command \
            content_adult_global content_vulgar_global} {
        if {![info exists config($key)]} {
            continue
        }
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

    set lang [string tolower [string trim $config(db_lang)]]
    if {![regexp {^[a-z0-9]{1,8}$} $lang]} {
        return -code error "Configuration ClaraServ invalide : config(db_lang) doit être alphanumérique court (ex. fr, en)."
    }
    set config(db_lang) $lang

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

# Cible multi-mots : trim, CR/LF→espace, séquences couleur IRC, puis C0/DEL.
proc ::ClaraServ::FCT::Parse:Target {raw} {
    regsub -all {[\r\n]+} $raw { } raw
    set raw [string trim $raw]
    regsub -all {\x03[0-9]{0,2}(,[0-9]{0,2})?} $raw {} raw
    regsub -all {[\x00-\x1f\x7f]} $raw {} raw
    return [string trim $raw]
}

# UID TS6 Unreal typique : 3 (SID) + 6 = 9 caractères alphanum.
proc ::ClaraServ::FCT::Looks:Like:Uid {token} {
    return [regexp {^[0-9][A-Za-z0-9]{2}[A-Za-z0-9]{6}$} $token]
}

proc ::ClaraServ::FCT::Nickmap:Set {uid nick} {
    variable ::ClaraServ::nickByUid
    variable ::ClaraServ::uidByNick
    set uid [string toupper [string trim $uid]]
    set nick [string trim $nick]
    if {$uid eq "" || $nick eq ""} {
        return
    }
    if {[info exists nickByUid($uid)]} {
        set oldNick $nickByUid($uid)
        if {[info exists uidByNick([string toupper $oldNick])]} {
            unset uidByNick([string toupper $oldNick])
        }
    }
    if {[info exists uidByNick([string toupper $nick])]} {
        set oldUid $uidByNick([string toupper $nick])
        if {$oldUid ne $uid && [info exists nickByUid($oldUid)]} {
            unset nickByUid($oldUid)
        }
    }
    set nickByUid($uid) $nick
    set uidByNick([string toupper $nick]) $uid
}

proc ::ClaraServ::FCT::Nickmap:Remove:Uid {uid} {
    variable ::ClaraServ::nickByUid
    variable ::ClaraServ::uidByNick
    set uid [string toupper [string trim $uid]]
    if {![info exists nickByUid($uid)]} {
        return
    }
    set nick $nickByUid($uid)
    unset nickByUid($uid)
    if {[info exists uidByNick([string toupper $nick])]} {
        unset uidByNick([string toupper $nick])
    }
}

# Préfère un nick affichable. Ne convertit jamais un nick → UID
# (UID_CONVERT IRCServices est bidirectionnel).
proc ::ClaraServ::FCT::Nickmap:Resolve {token} {
    variable ::ClaraServ::nickByUid
    variable ::ClaraServ::CONNECT_ID
    set token [string trim $token]
    if {$token eq ""} {
        return $token
    }
    if {![::ClaraServ::FCT::Looks:Like:Uid $token]} {
        return $token
    }
    set key [string toupper $token]
    if {[info exists nickByUid($key)]} {
        return $nickByUid($key)
    }
    if {$CONNECT_ID ne "" && [info commands ${CONNECT_ID}::UID_CONVERT] ne ""} {
        set converted [${CONNECT_ID}::UID_CONVERT $token]
        if {$converted ne "" && $converted ne $token \
                && ![::ClaraServ::FCT::Looks:Like:Uid $converted]} {
            return $converted
        }
    }
    return $token
}

proc ::ClaraServ::FCT::Display:Nick {token} {
    return [::ClaraServ::FCT::Sanitize:Irc:Text [::ClaraServ::FCT::Nickmap:Resolve $token]]
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
    foreach meta {!help !cmds !alias !about !random} {
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

# Lit un fichier données en ignorant les commentaires # et lignes vides (pas de source/eval).
proc ::ClaraServ::FCT::DB:Read:Data:Lines {path} {
    set fh [open $path r]
    try {
        fconfigure $fh -encoding utf-8
        set lines {}
        while {[gets $fh line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq "" || [string match "#*" $trimmed]} {
                continue
            }
            lappend lines $trimmed
        }
        return $lines
    } finally {
        close $fh
    }
}

# Charge aliases : une ligne « !alias !canonique » par entrée.
proc ::ClaraServ::FCT::DB:LoadAliases {path} {
    variable ::ClaraServ::aliasesDict
    variable ::ClaraServ::commandResponses
    variable ::ClaraServ::randomExcludeCommands

    set newDict [dict create]
    set brandDeny [list !heineken !leffe !stella !despe !1664 !guinness !coca !banania]
    foreach line [::ClaraServ::FCT::DB:Read:Data:Lines $path] {
        set parts [regexp -all -inline {\S+} $line]
        if {[llength $parts] != 2} {
            return -code error "Alias invalide (attendu « !alias !canonique ») : $line"
        }
        set aliasName [::ClaraServ::FCT::Command:Normalise [lindex $parts 0]]
        set targetName [::ClaraServ::FCT::Command:Normalise [lindex $parts 1]]
        if {![string match "\!*" $aliasName] || ![string match "\!*" $targetName]} {
            return -code error "Alias invalide (préfixe ! requis) : $line"
        }
        if {$aliasName in $brandDeny || $targetName in $brandDeny} {
            return -code error "Alias marque refusé : $line"
        }
        foreach blocked $randomExcludeCommands {
            if {$targetName eq [::ClaraServ::FCT::Command:Normalise $blocked]} {
                return -code error "Alias vers commande sensible refusé : $line"
            }
        }
        if {![dict exists $commandResponses $targetName]} {
            return -code error "Alias vers commande inexistante : $line"
        }
        if {[dict exists $commandResponses $aliasName]} {
            return -code error "Alias en collision avec une commande canonique : $aliasName"
        }
        if {[dict exists $newDict $aliasName]} {
            return -code error "Alias dupliqué : $aliasName"
        }
        dict set newDict $aliasName $targetName
    }
    # Pas d’alias → alias (cible doit être canonique, déjà vérifié via commandResponses).
    foreach {aliasName targetName} $newDict {
        if {[dict exists $newDict $targetName]} {
            return -code error "Alias vers un autre alias refusé : $aliasName → $targetName"
        }
    }
    set aliasesDict $newDict
    return [dict size $aliasesDict]
}

# Préfixe optionnel « [adult] » / « [vulgar] » / « [adult vulgar] » sur une ligne de variante.
proc ::ClaraServ::FCT::DB:Parse:Variant:Line {line} {
    set tags {}
    if {[regexp -nocase {^\[([^\]]+)\]\s+(.*)$} $line -> tagStr rest]} {
        foreach chunk [split $tagStr {,}] {
            foreach raw [split [string trim $chunk]] {
                set t [string tolower [string trim $raw]]
                if {$t in {adult vulgar} && $t ni $tags} {
                    lappend tags $t
                }
            }
        }
        return [dict create text $rest tags $tags]
    }
    return [dict create text $line tags {}]
}

# Charge variants : en-tête « !cmd 0|1 » puis entrées {text tags} jusqu’au prochain en-tête.
# Plusieurs blocs pour la même clé (!cmd niveau) sont **fusionnés** (pas écrasés) —
# ex. variantes soft puis bloc DuckHunt [adult]/[vulgar] plus bas dans le fichier.
proc ::ClaraServ::FCT::DB:Load:Text:Sections {path {asEntries 1}} {
    set result [dict create]
    set currentKey {}
    set bucket {}
    foreach line [::ClaraServ::FCT::DB:Read:Data:Lines $path] {
        if {[regexp {^(![^\s]+)\s+([01])$} $line -> cmd level]} {
            if {$currentKey ne "" && [llength $bucket] > 0} {
                if {[dict exists $result $currentKey]} {
                    dict set result $currentKey [concat [dict get $result $currentKey] $bucket]
                } else {
                    dict set result $currentKey $bucket
                }
            }
            set norm [::ClaraServ::FCT::Command:Normalise $cmd]
            set currentKey [list $norm $level]
            set bucket {}
            continue
        }
        if {$currentKey eq ""} {
            return -code error "Texte hors section (manque en-tête !cmd niveau) : $line"
        }
        set entry [::ClaraServ::FCT::DB:Parse:Variant:Line $line]
        if {$asEntries} {
            lappend bucket $entry
        } else {
            lappend bucket [dict get $entry text]
        }
    }
    if {$currentKey ne "" && [llength $bucket] > 0} {
        if {[dict exists $result $currentKey]} {
            dict set result $currentKey [concat [dict get $result $currentKey] $bucket]
        } else {
            dict set result $currentKey $bucket
        }
    }
    return $result
}

proc ::ClaraServ::FCT::DB:LoadVariants {path} {
    variable ::ClaraServ::variantsDict
    set variantsDict [::ClaraServ::FCT::DB:Load:Text:Sections $path 1]
    return [dict size $variantsDict]
}

proc ::ClaraServ::FCT::DB:LoadFails {path} {
    variable ::ClaraServ::failsDict
    # Fails : textes seuls (préfixe tag ignoré s’il apparaît).
    set failsDict [::ClaraServ::FCT::DB:Load:Text:Sections $path 0]
    return [dict size $failsDict]
}

proc ::ClaraServ::FCT::DB:ResolveAlias {command} {
    variable ::ClaraServ::aliasesDict
    set normalised [::ClaraServ::FCT::Command:Normalise $command]
    if {[dict exists $aliasesDict $normalised]} {
        return [dict get $aliasesDict $normalised]
    }
    return $normalised
}

# Entrées structurées (historique + variants.db) pour filtrage contenu.
proc ::ClaraServ::FCT::DB:GetVariantEntries {command level} {
    variable ::ClaraServ::variantsDict
    set normalised [::ClaraServ::FCT::Command:Normalise $command]
    set key [list $normalised $level]
    set historical [::ClaraServ::FCT::DB:GET $normalised $level]
    set extras {}
    if {[dict exists $variantsDict $key]} {
        set extras [dict get $variantsDict $key]
    }
    set entries {}
    set seenTexts {}
    if {$historical ne "-1"} {
        lappend entries [dict create text $historical tags {}]
        dict set seenTexts $historical 1
    }
    foreach entry $extras {
        set text [dict get $entry text]
        if {[dict exists $seenTexts $text]} {
            continue
        }
        dict set seenTexts $text 1
        lappend entries $entry
    }
    return $entries
}

proc ::ClaraServ::FCT::DB:GetVariants {command level} {
    set texts {}
    foreach entry [::ClaraServ::FCT::DB:GetVariantEntries $command $level] {
        lappend texts [dict get $entry text]
    }
    return $texts
}

proc ::ClaraServ::FCT::DB:GetFails {command level} {
    variable ::ClaraServ::failsDict
    set normalised [::ClaraServ::FCT::Command:Normalise $command]
    set key [list $normalised $level]
    if {[dict exists $failsDict $key]} {
        return [dict get $failsDict $key]
    }
    return {}
}

proc ::ClaraServ::FCT::DB:ChooseVariant {variants} {
    variable ::ClaraServ::randForceIndex
    set n [llength $variants]
    if {$n == 0} {
        return ""
    }
    if {$n == 1} {
        return [lindex $variants 0]
    }
    if {[string is integer -strict $randForceIndex] && $randForceIndex >= 0} {
        return [lindex $variants [expr {$randForceIndex % $n}]]
    }
    return [lindex $variants [expr {int(rand() * $n)}]]
}

# --- Gates contenu adult / vulgar (global + salon) ---

proc ::ClaraServ::FCT::Content:Global:Enabled {tag} {
    variable ::ClaraServ::config
    set tag [string tolower $tag]
    if {$tag eq "adult"} {
        if {![info exists config(content_adult_global)]} {
            return 0
        }
        return [expr {$config(content_adult_global) ? 1 : 0}]
    }
    if {$tag eq "vulgar"} {
        if {![info exists config(content_vulgar_global)]} {
            return 0
        }
        return [expr {$config(content_vulgar_global) ? 1 : 0}]
    }
    return 1
}

proc ::ClaraServ::FCT::Content:Salon:Enabled {channel tag} {
    variable ::ClaraServ::salonFlags
    set channel [string tolower [string trim $channel]]
    set tag [string tolower $tag]
    if {![dict exists $salonFlags $channel]} {
        return 0
    }
    set flags [dict get $salonFlags $channel]
    if {![dict exists $flags $tag]} {
        return 0
    }
    return [expr {[dict get $flags $tag] ? 1 : 0}]
}

# Tag autorisé sur ce salon ssi global ON et salon ON (sauf tags hors adult/vulgar).
proc ::ClaraServ::FCT::Content:Tag:Allowed {channel tag} {
    set tag [string tolower $tag]
    if {$tag ni {adult vulgar}} {
        return 1
    }
    if {![::ClaraServ::FCT::Content:Global:Enabled $tag]} {
        return 0
    }
    return [::ClaraServ::FCT::Content:Salon:Enabled $channel $tag]
}

proc ::ClaraServ::FCT::DB:Filter:Content {channel entries} {
    set out {}
    foreach entry $entries {
        set ok 1
        foreach tag [dict get $entry tags] {
            if {![::ClaraServ::FCT::Content:Tag:Allowed $channel $tag]} {
                set ok 0
                break
            }
        }
        if {$ok} {
            lappend out $entry
        }
    }
    return $out
}

proc ::ClaraServ::FCT::DB:Entry:Texts {entries} {
    set texts {}
    foreach entry $entries {
        lappend texts [dict get $entry text]
    }
    return $texts
}

proc ::ClaraServ::FCT::SalonFlags:Path {} {
    variable ::ClaraServ::salonFlagsPathOverride
    if {[info exists salonFlagsPathOverride] && $salonFlagsPathOverride ne ""} {
        return $salonFlagsPathOverride
    }
    return [file join [::ClaraServ::FCT::Get:ScriptDir db] salon_flags.db]
}

proc ::ClaraServ::FCT::SalonFlags:Load {} {
    variable ::ClaraServ::salonFlags
    set salonFlags [dict create]
    set path [::ClaraServ::FCT::SalonFlags:Path]
    if {![file exists $path]} {
        return 0
    }
    set fh [open $path r]
    try {
        while {[gets $fh line] >= 0} {
            set line [string trim $line]
            if {$line eq "" || [string match "#*" $line]} {
                continue
            }
            # #salon adult 0|1 vulgar 0|1
            if {![regexp -nocase {^(#[^\s]+)\s+adult\s+([01])\s+vulgar\s+([01])$} $line -> ch a v]} {
                ::ClaraServ::log warn "salon_flags.db : ligne ignorée"
                continue
            }
            if {![::ClaraServ::FCT::Channel:IsValid $ch]} {
                continue
            }
            set ch [string tolower $ch]
            set adult $a
            set vulgar $v
            # Impossible d’avoir un flag salon ON si le global est OFF.
            if {$adult && ![::ClaraServ::FCT::Content:Global:Enabled adult]} {
                set adult 0
            }
            if {$vulgar && ![::ClaraServ::FCT::Content:Global:Enabled vulgar]} {
                set vulgar 0
            }
            dict set salonFlags $ch [dict create adult $adult vulgar $vulgar]
        }
    } finally {
        close $fh
    }
    return [dict size $salonFlags]
}

proc ::ClaraServ::FCT::SalonFlags:Save {} {
    variable ::ClaraServ::salonFlags
    set path [::ClaraServ::FCT::SalonFlags:Path]
    set lines {}
    lappend lines "# ClaraServ salon_flags.db — runtime, non versionné"
    lappend lines "# Format : #salon adult 0|1 vulgar 0|1"
    foreach ch [lsort [dict keys $salonFlags]] {
        set flags [dict get $salonFlags $ch]
        set a 0
        set v 0
        if {[dict exists $flags adult]} { set a [dict get $flags adult] }
        if {[dict exists $flags vulgar]} { set v [dict get $flags vulgar] }
        lappend lines [format "%s adult %d vulgar %d" $ch $a $v]
    }
    set temporaryFile "${path}.[pid].tmp"
    set fh [open $temporaryFile w]
    try {
        foreach line $lines {
            puts $fh $line
        }
    } finally {
        close $fh
    }
    file rename -force $temporaryFile $path
    return 1
}

# Définit un flag salon ; refuse ON si global OFF. Retourne message statut.
proc ::ClaraServ::FCT::SalonFlags:Set {channel tag value} {
    variable ::ClaraServ::salonFlags
    set channel [string tolower [string trim $channel]]
    set tag [string tolower [string trim $tag]]
    set value [expr {$value ? 1 : 0}]
    if {$tag ni {adult vulgar}} {
        return -code error "flag inconnu (adult|vulgar)"
    }
    if {$value && ![::ClaraServ::FCT::Content:Global:Enabled $tag]} {
        return -code error "flag global $tag désactivé dans ClaraServ.conf"
    }
    if {![dict exists $salonFlags $channel]} {
        dict set salonFlags $channel [dict create adult 0 vulgar 0]
    }
    dict set salonFlags $channel $tag $value
    ::ClaraServ::FCT::SalonFlags:Save
    return 1
}

proc ::ClaraServ::FCT::SalonFlags:Status:Text {channel} {
    set channel [string tolower [string trim $channel]]
    set ga [::ClaraServ::FCT::Content:Global:Enabled adult]
    set gv [::ClaraServ::FCT::Content:Global:Enabled vulgar]
    set sa [::ClaraServ::FCT::Content:Salon:Enabled $channel adult]
    set sv [::ClaraServ::FCT::Content:Salon:Enabled $channel vulgar]
    set ea [expr {$ga && $sa}]
    set ev [expr {$gv && $sv}]
    return [format "salon %s : adult global=%d salon=%d effectif=%d | vulgar global=%d salon=%d effectif=%d" \
        $channel $ga $sa $ea $gv $sv $ev]
}

# --- Ops @ (suivi MODE) ---

proc ::ClaraServ::FCT::ChanOp:Key {channel uidOrNick} {
    set channel [string toupper [string trim $channel]]
    set id [string toupper [string trim $uidOrNick]]
    return [format "%s\0%s" $channel $id]
}

proc ::ClaraServ::FCT::ChanOp:Set {channel uidOrNick on} {
    variable ::ClaraServ::chanOps
    set key [::ClaraServ::FCT::ChanOp:Key $channel $uidOrNick]
    if {$on} {
        set chanOps($key) 1
    } elseif {[info exists chanOps($key)]} {
        unset chanOps($key)
    }
}

proc ::ClaraServ::FCT::ChanOp:Is {channel sender} {
    variable ::ClaraServ::chanOps
    variable ::ClaraServ::uidByNick
    set channel [string trim $channel]
    set sender [string trim $sender]
    if {$channel eq "" || $sender eq ""} {
        return 0
    }
    set key [::ClaraServ::FCT::ChanOp:Key $channel $sender]
    if {[info exists chanOps($key)]} {
        return 1
    }
    # Si sender est un nick, tenter via UID mappé.
    if {![::ClaraServ::FCT::Looks:Like:Uid $sender]} {
        set nk [string toupper $sender]
        if {[info exists uidByNick($nk)]} {
            set key2 [::ClaraServ::FCT::ChanOp:Key $channel $uidByNick($nk)]
            if {[info exists chanOps($key2)]} {
                return 1
            }
        }
    }
    return 0
}

# Applique une chaîne de modes salon (+o/-o …) avec arguments positionnels.
proc ::ClaraServ::FCT::ChanOp:ApplyMode {channel modeStr argList} {
    set channel [string trim $channel]
    if {![::ClaraServ::FCT::Channel:IsValid $channel]} {
        return
    }
    set sign "+"
    set argIdx 0
    foreach ch [split $modeStr {}] {
        if {$ch eq "+" || $ch eq "-"} {
            set sign $ch
            continue
        }
        # Modes avec argument nick/UID courants Unreal (o/v/h/a/q/b/e/I/k).
        if {$ch in {o v h a q b e I k}} {
            set target [lindex $argList $argIdx]
            incr argIdx
            if {$target eq ""} {
                continue
            }
            if {$ch eq "o"} {
                ::ClaraServ::FCT::ChanOp:Set $channel $target [expr {$sign eq "+"}]
            }
        }
    }
}

# Admin (mdp) ou @ du salon si déjà observé via MODE.
proc ::ClaraServ::FCT::Auth:Admin:Or:ChanOp {sender channel password} {
    variable ::ClaraServ::config
    if {$password ne "" && [string equal $password $config(admin_password)]} {
        return 1
    }
    if {[::ClaraServ::FCT::Channel:IsValid $channel] \
            && [::ClaraServ::FCT::ChanOp:Is $channel $sender]} {
        return 1
    }
    return 0
}

proc ::ClaraServ::FCT::DB:ShouldFail {command level} {
    variable ::ClaraServ::failRate
    variable ::ClaraServ::randForceFail
    if {![string is integer -strict $failRate] || $failRate <= 0} {
        return 0
    }
    if {[llength [::ClaraServ::FCT::DB:GetFails $command $level]] == 0} {
        return 0
    }
    if {$randForceFail ne ""} {
        return [expr {$randForceFail ? 1 : 0}]
    }
    set capped $failRate
    if {$capped > 100} {
        set capped 100
    }
    return [expr {int(rand() * 100) < $capped}]
}

proc ::ClaraServ::FCT::Render:Template {template sender pseudo keyword destination} {
    set response [::ZCT::TXT::REPLACE_SUBSTITUTE $template $destination]
    return [string map [list \
        %pseudo% $pseudo \
        %sender% $sender \
        %keyword% $keyword \
        %destination% $destination \
    ] $response]
}

proc ::ClaraServ::FCT::RateLimit:Cleanup {now} {
    variable ::ClaraServ::rateLimit
    foreach key [array names rateLimit] {
        if {($now - $rateLimit($key)) > 60} {
            unset rateLimit($key)
        }
    }
}

# Identité stable pour anti-flood : UID TS6 si possible, sinon nick normalisé.
proc ::ClaraServ::FCT::RateLimit:Identity {sender} {
    variable ::ClaraServ::uidByNick
    set s [string trim $sender]
    if {$s eq ""} {
        return {}
    }
    if {[::ClaraServ::FCT::Looks:Like:Uid $s]} {
        return [string toupper $s]
    }
    set key [string toupper $s]
    if {[info exists uidByNick($key)]} {
        return $uidByNick($key)
    }
    return $key
}

# Retourne 1 si le cooldown autorise encore (ne marque pas). bypass=1 ignore.
proc ::ClaraServ::FCT::RateLimit:Allowed {salon sender {bypass 0}} {
    variable ::ClaraServ::rateLimitCooldown
    variable ::ClaraServ::rateLimit

    if {$bypass || ![string is integer -strict $rateLimitCooldown] || $rateLimitCooldown <= 0} {
        return 1
    }
    set now [clock seconds]
    ::ClaraServ::FCT::RateLimit:Cleanup $now
    set key [list $salon [::ClaraServ::FCT::RateLimit:Identity $sender]]
    if {[info exists rateLimit($key)]} {
        if {($now - $rateLimit($key)) < $rateLimitCooldown} {
            return 0
        }
    }
    return 1
}

# Enregistre le timestamp après un envoi réussi.
proc ::ClaraServ::FCT::RateLimit:Commit {salon sender} {
    variable ::ClaraServ::rateLimitCooldown
    variable ::ClaraServ::rateLimit
    if {![string is integer -strict $rateLimitCooldown] || $rateLimitCooldown <= 0} {
        return
    }
    set rateLimit([list $salon [::ClaraServ::FCT::RateLimit:Identity $sender]]) [clock seconds]
}

proc ::ClaraServ::FCT::DB:Load:Enrichment:Files {} {
    set aliasesPath [file join [::ClaraServ::FCT::Get:ScriptDir db] aliases.fr.db]
    set variantsPath [file join [::ClaraServ::FCT::Get:ScriptDir db] variants.fr.db]
    set failsPath [file join [::ClaraServ::FCT::Get:ScriptDir db] fails.fr.db]

    variable ::ClaraServ::aliasesDict
    variable ::ClaraServ::variantsDict
    variable ::ClaraServ::failsDict
    set aliasesDict [dict create]
    set variantsDict [dict create]
    set failsDict [dict create]

    if {[file exists $aliasesPath]} {
        ::ClaraServ::FCT::DB:LoadAliases $aliasesPath
    }
    if {[file exists $variantsPath]} {
        ::ClaraServ::FCT::DB:LoadVariants $variantsPath
    }
    if {[file exists $failsPath]} {
        ::ClaraServ::FCT::DB:LoadFails $failsPath
    }
}

proc ::ClaraServ::FCT::DB:Apply:Runtime:Config {} {
    variable ::ClaraServ::config
    variable ::ClaraServ::failRate
    variable ::ClaraServ::rateLimitCooldown

    if {[info exists config(failrate)] && [string is integer -strict $config(failrate)]} {
        set failRate $config(failrate)
    }
    if {[info exists config(rate_limit_cooldown)] && [string is integer -strict $config(rate_limit_cooldown)]} {
        set rateLimitCooldown $config(rate_limit_cooldown)
    }
}

# Recharge database.<lang>.db + aliases/variants/fails (pas ClaraServ.conf).
proc ::ClaraServ::FCT::DB:Reload:Animations {} {
    variable ::ClaraServ::config
    variable ::ClaraServ::database
    variable ::ClaraServ::commandResponses
    variable ::ClaraServ::commandLabels
    variable ::ClaraServ::commandNames
    variable ::ClaraServ::aliasesDict
    variable ::ClaraServ::variantsDict
    variable ::ClaraServ::failsDict

    set snapDb $database
    set snapResp $commandResponses
    set snapLabels $commandLabels
    set snapNames $commandNames
    set snapAliases $aliasesDict
    set snapVariants $variantsDict
    set snapFails $failsDict

    if {[catch {
        set animationDatabase [file join [::ClaraServ::FCT::Get:ScriptDir db] $config(FILE_DB)]
        if {![file exists $animationDatabase]} {
            return -code error "Base d’animations introuvable : $animationDatabase"
        }
        set database {}
        namespace eval ::ClaraServ [list source $animationDatabase]
        ::ClaraServ::FCT::DB:Index
        ::ClaraServ::FCT::DB:Load:Enrichment:Files
    } err]} {
        set database $snapDb
        set commandResponses $snapResp
        set commandLabels $snapLabels
        set commandNames $snapNames
        set aliasesDict $snapAliases
        set variantsDict $snapVariants
        set failsDict $snapFails
        return -code error "Reload animations échoué (état précédent conservé) : $err"
    }
    return 1
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
    # 1 = déjà présent ; 0 = absent ; -1 = fichier manquant (traité comme vide).
    if {[::ClaraServ::FCT::DB:DATA:EXIST salon $channel] == 1} {
        return -1
    }

    set databaseFile [file join [::ClaraServ::FCT::Get:ScriptDir db] salon.db]
    set retainedLines {}
    if {[file exists $databaseFile]} {
        set fileHandle [open $databaseFile r]
        try {
            while {[gets $fileHandle line] >= 0} {
                set line [string trim $line]
                if {$line ne ""} {
                    lappend retainedLines $line
                }
            }
        } finally {
            close $fileHandle
        }
    }
    lappend retainedLines $channel

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

proc ::ClaraServ::FCT::CMD:SHOW:ALIASES {destination} {
    variable ::ClaraServ::aliasesDict
    if {[dict size $aliasesDict] == 0} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
            "<c04>.: <c12>Aucun alias n’est configuré.<s>"
        return 0
    }
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        "<c04>.: <c12>Alias → commande canonique<c04> :.<s>"
    set maximumPerLine 6
    set lineParts {}
    set count 0
    foreach aliasName [lsort -dictionary [dict keys $aliasesDict]] {
        set targetName [dict get $aliasesDict $aliasName]
        lappend lineParts [format "<c07>%s<c12>→<c06>%s" $aliasName $targetName]
        incr count
        if {$count >= $maximumPerLine} {
            ::ClaraServ::FCT::SENT:MSG:TO:USER $destination [join $lineParts " <c12>|<c12> "]
            set lineParts {}
            set count 0
        }
    }
    if {[llength $lineParts] > 0} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $destination [join $lineParts " <c12>|<c12> "]
    }
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>%d alias(s). Les formes sans accent (!cafe, !biere, …) matchent déjà via normalisation.<s>" \
            [dict size $aliasesDict]]
    return 1
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
    # $sender = identifiant routage (souvent UID TS6). Tout texte visible
    # doit passer par Display:Nick (jamais $sender brut dans une annonce salon).
    set senderId $sender

    set words [::ClaraServ::FCT::Message:Words $message]
    if {[llength $words] == 0} {
        return 0
    }

    set command [::ClaraServ::FCT::Command:Normalise [lindex $words 0]]
    set data [lrange $words 1 end]

    if {[string index $destination 0] ne "#"} {
        set procedure "::ClaraServ::IRC:CMD:PRIV:[string toupper $command]"
        if {[info commands $procedure] eq ""} {
            ::ClaraServ::FCT::SENT:MSG:TO:USER $senderId [format "Commande %s inconnue." $command]
            return [::ClaraServ::IRC:CMD:PRIV:HELP $senderId $destination $command $data]
        }
        return [::ClaraServ::FCT::Dispatch:Command $procedure $senderId $destination $command $data]
    }

    if {![string match "!*" $command]} {
        return 0
    }

    set commandName [string range $command 1 end]
    set procedure "::ClaraServ::IRC:CMD:PUB:[string toupper $commandName]"
    if {[info commands $procedure] ne ""} {
        return [::ClaraServ::FCT::Dispatch:Command $procedure $senderId $destination $command $data]
    }

    if {[::ClaraServ::FCT::DB:GET [::ClaraServ::FCT::DB:ResolveAlias $command] 0] ne "-1"} {
        return [::ClaraServ::FCT::Dispatch:Command ::ClaraServ::IRC:CMD:PUB:DYNAMIC $senderId $destination $command $data]
    }
    return [::ClaraServ::FCT::Reply:Unknown:Public $senderId $command]
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
    ::ClaraServ::FCT::DB:Apply:Runtime:Config

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
    ::ClaraServ::FCT::DB:Load:Enrichment:Files
    ::ClaraServ::FCT::SalonFlags:Load

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
    if {[file exists $pidFile]} {
        set oldPid ""
        if {[catch {
            set pfh [open $pidFile r]
            try {
                gets $pfh oldPid
            } finally {
                close $pfh
            }
        }]} {
            set oldPid ""
        }
        set oldPid [string trim $oldPid]
        if {[string is integer -strict $oldPid] && $oldPid > 1 && [file exists [file join /proc $oldPid]]} {
            return -code error "ClaraServ semble déjà actif (PID $oldPid, runtime $runDir). Arrêtez l’instance ou changez runtime_dir/instance_name."
        }
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
        if {${::ClaraServ::config(service_chanmodes)} ne ""} {
            [sid] mode ${::ClaraServ::config(service_channel)} ${::ClaraServ::config(service_chanmodes)}
        }
        if {${::ClaraServ::config(service_usermodes)} ne ""} {
            [sid] mode ${::ClaraServ::config(service_channel)} ${::ClaraServ::config(service_usermodes)} ${::ClaraServ::config(service_nick)}
        }

        set channelsFile [file join [::ClaraServ::FCT::Get:ScriptDir db] salon.db]
        if {[catch {open $channelsFile r} channelsHandle]} {
            ::ClaraServ::log warn "Impossible d’ouvrir salon.db au EOS : $channelsHandle"
        } else {
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
    }

    $BOT_ID registerevent PRIVMSG {
        # who = préfixe IRC (souvent UID TS6) ; who2 = UID_CONVERT bidirectionnel (peut être stale après NICK).
        # Router en UID ; n’apprendre depuis who2 que si Nickmap n’a pas encore d’entrée pour cet UID.
        set w [who]
        set w2 [who2]
        if {[::ClaraServ::FCT::Looks:Like:Uid $w]} {
            set senderId $w
            set ukey [string toupper $w]
            if {![info exists ::ClaraServ::nickByUid($ukey)] \
                    && $w2 ne "" && ![::ClaraServ::FCT::Looks:Like:Uid $w2]} {
                ::ClaraServ::FCT::Nickmap:Set $w $w2
            }
        } elseif {[::ClaraServ::FCT::Looks:Like:Uid $w2]} {
            set senderId $w2
            set ukey [string toupper $w2]
            if {![info exists ::ClaraServ::nickByUid($ukey)] \
                    && $w ne "" && ![::ClaraServ::FCT::Looks:Like:Uid $w]} {
                ::ClaraServ::FCT::Nickmap:Set $w2 $w
            }
        } else {
            set senderId $w2
            if {$senderId eq ""} {
                set senderId $w
            }
        }
        ::ClaraServ::FCT::Dispatch:Message $senderId [target] [msg]
    }

    # Suivi UID↔nick (corrige l’affichage quand who2 reste un UID TS6).
    $CONNECT_ID registerevent UID {
        set add [additional]
        if {[llength $add] >= 5} {
            ::ClaraServ::FCT::Nickmap:Set [lindex $add 4] [target]
        }
    }
    $CONNECT_ID registerevent NICK {
        set src [who]
        set newNick [target]
        if {$newNick eq "" && [msg] ne ""} {
            set newNick [lindex [regexp -all -inline {\S+} [msg]] 0]
        }
        if {$newNick ne ""} {
            ::ClaraServ::FCT::Nickmap:Set $src $newNick
        }
    }
    $CONNECT_ID registerevent QUIT {
        ::ClaraServ::FCT::Nickmap:Remove:Uid [who]
    }

    # Suivi @ salon (+o/-o) pour auth chanflag sans mdp admin.
    $CONNECT_ID registerevent MODE {
        set dest [target]
        if {![string match "#*" $dest]} {
            return
        }
        set add [additional]
        set modeStr [lindex $add 0]
        set args [lrange $add 1 end]
        if {$modeStr eq "" && [msg] ne ""} {
            set words [regexp -all -inline {\S+} [msg]]
            set modeStr [lindex $words 0]
            set args [lrange $words 1 end]
        }
        if {$modeStr ne ""} {
            ::ClaraServ::FCT::ChanOp:ApplyMode $dest $modeStr $args
        }
    }

    # ERROR uplink (auth/SID/…) : IRCServices ne dispatchait pas — patch local + handler ici.
    $CONNECT_ID registerevent ERROR {
        ::ClaraServ::log error "ERROR reçu de l’uplink — arrêt du processus."
        ::ClaraServ::FCT::Request:Shutdown uplink-error 1
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

    # Pas de rate-limit ici : DYNAMIC l’applique une seule fois (évite un double cooldown
    # qui faisait échouer !random systématiquement).

    if {[llength $data] == 0} {
        set level 0
    } else {
        set level 1
        if {[::ClaraServ::FCT::Parse:Target [join $data " "]] eq ""} {
            set level 0
        }
    }

    set commands {}
    foreach candidate [::ClaraServ::FCT::DB:CMD:LIST] {
        set resolved [::ClaraServ::FCT::DB:ResolveAlias $candidate]
        set normalised [::ClaraServ::FCT::Command:Normalise $resolved]
        set excluded 0
        foreach blocked $randomExcludeCommands {
            if {$normalised eq [::ClaraServ::FCT::Command:Normalise $blocked]} {
                set excluded 1
                break
            }
        }
        if {$excluded} {
            continue
        }
        set playable [::ClaraServ::FCT::DB:Filter:Content $destination \
            [::ClaraServ::FCT::DB:GetVariantEntries $resolved $level]]
        if {[llength $playable] == 0} {
            continue
        }
        lappend commands $candidate
    }
    if {[llength $commands] == 0} {
        # Notice privée à l’auteur — $destination est le salon.
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Aucune animation n’est disponible."
        return 0
    }

    set randomCommand [lindex $commands [expr {int(rand() * [llength $commands])}]]
    return [::ClaraServ::IRC:CMD:PUB:DYNAMIC $sender $destination $randomCommand $data]
}

proc ::ClaraServ::IRC:CMD:PUB:DYNAMIC {sender destination command data} {
    if {![::ClaraServ::FCT::RateLimit:Allowed $destination $sender]} {
        return 0
    }

    set typedCommand [::ClaraServ::FCT::Command:Normalise $command]
    set keyword [string range $typedCommand 1 end]
    set resolved [::ClaraServ::FCT::DB:ResolveAlias $typedCommand]
    set senderDisplay [::ClaraServ::FCT::Sanitize:Irc:Text [::ClaraServ::FCT::Display:Nick $sender]]

    if {[llength $data] == 0} {
        set level 0
        set pseudo ""
    } else {
        set level 1
        set pseudo [::ClaraServ::FCT::Parse:Target [join $data " "]]
        if {$pseudo eq ""} {
            set level 0
        }
    }

    set entries [::ClaraServ::FCT::DB:GetVariantEntries $resolved $level]
    set entries [::ClaraServ::FCT::DB:Filter:Content $destination $entries]
    if {[llength $entries] == 0} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender \
            "Contenu désactivé pour ce salon (gates adult/vulgar). Demandez à un op ou à l’admin."
        return 0
    }

    set variants [::ClaraServ::FCT::DB:Entry:Texts $entries]
    if {[::ClaraServ::FCT::DB:ShouldFail $resolved $level]} {
        set fails [::ClaraServ::FCT::DB:GetFails $resolved $level]
        if {[llength $fails] > 0} {
            set variants $fails
        }
    }

    set response [::ClaraServ::FCT::DB:ChooseVariant $variants]
    if {$response eq ""} {
        return 0
    }

    set response [::ClaraServ::FCT::Render:Template $response $senderDisplay $pseudo $keyword $destination]
    ::ClaraServ::FCT::SENT:PRIVMSG $destination $response
    ::ClaraServ::FCT::RateLimit:Commit $destination $sender
    ::ClaraServ::FCT::Log:Command $typedCommand $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PUB:CMDS {sender destination command data} {
    set shown [::ClaraServ::FCT::Display:Nick $sender]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Liste des commandes envoyée en privé à %s<c04> :.<s>" $shown]
    return [::ClaraServ::IRC:CMD:PRIV:CMDS $sender $destination $command $data]
}

proc ::ClaraServ::IRC:CMD:PRIV:CMDS {sender destination command data} {
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Liste des commandes d’animations<c04> :.<s>"
    ::ClaraServ::FCT::CMD:SHOW:LIST $sender
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender \
        "<c04>.: <c12>Alias<c04> : <c06>!alias<c12> (ou <c06>alias<c12> en privé) pour la liste des liens.<s>"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Autres commandes<c04> :.<s>"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!help <c12>-<c04> Affiche l’aide"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!alias <c12>-<c04> Liste alias → commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!<s><<c06>commande<s>> \[<c06>cible multi-mots<s>\] <c12>-<c04> Exécute une animation"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c12>!random <s>\[<c06>cible<s>\] <c12>-<c04> Choisit une animation aléatoire"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c12>!about <c12>-<c04> Affiche les informations sur %s" ${::ClaraServ::config(service_nick)}]
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PUB:ALIAS {sender destination command data} {
    set shown [::ClaraServ::FCT::Display:Nick $sender]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Liste des alias envoyée en privé à %s<c04> :.<s>" $shown]
    return [::ClaraServ::IRC:CMD:PRIV:ALIAS $sender $destination $command $data]
}

proc ::ClaraServ::IRC:CMD:PRIV:ALIAS {sender destination command data} {
    ::ClaraServ::FCT::CMD:SHOW:ALIASES $sender
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PUB:ABOUT {sender destination command data} {
    set shown [::ClaraServ::FCT::Display:Nick $sender]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Informations de %s envoyées en privé à %s<c04> :." ${::ClaraServ::config(service_nick)} $shown]
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
    set shown [::ClaraServ::FCT::Display:Nick $sender]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $destination \
        [format "<c04>.: <c12>Aide envoyée en privé à %s<c04> :." $shown]
    return [::ClaraServ::IRC:CMD:PRIV:HELP $sender $destination $command $data]
}

proc ::ClaraServ::IRC:CMD:PRIV:HELP {sender destination command data} {
    variable ::ClaraServ::config
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Commandes en salon<c04> :."
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!help <c07>-<c06> Affiche cette aide"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!cmds <c07>-<c06> Affiche la liste des commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!alias <c07>-<c06> Affiche les alias → commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!<s><<c07>commande<s>> \[<c06>pseudonyme<s>\] <c07>-<c06> Exécute une animation"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>!random <s>\[<c06>pseudonyme<s>\] <c07>-<c06> Choisit une animation aléatoire"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>!about <c07>-<c06> À propos de %s" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c04>.: <c12>Commandes privées<c04> :."
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>help <c07>-<c06> Affiche cette aide"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>cmds <c07>-<c06> Affiche la liste des commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>alias <c07>-<c06> Affiche les alias → commandes"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>about <c07>-<c06> À propos de %s" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>join <s><<c06>#salon<s>> <<c06>mot_de_passe_admin<s>> <c07>-<c06> Ajoute %s au salon" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [format "<c07>part <s><<c06>#salon<s>> <<c06>mot_de_passe_admin<s>> <c07>-<c06> Retire %s du salon" $config(service_nick)]
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>reload <s><<c06>mot_de_passe_admin<s>> <c07>-<c06> Recharge les bases d’animations"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>chanflag <s><<c06>#salon<s>> <<c06>adult|vulgar<s>> <<c06>on|off<s>> \[<c06>mdp_admin<s>\] <c07>-<c06> Flag contenu salon"
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "<c07>chanflags <s><<c06>#salon<s>> \[<c06>mdp_admin<s>\] <c07>-<c06> Statut flags contenu"
    ::ClaraServ::FCT::Log:Command $command $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PRIV:RELOAD {sender destination command data} {
    variable ::ClaraServ::config

    set password [lindex $data 0]
    if {$password eq ""} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender \
            [format "Syntaxe : /msg %s reload <mot_de_passe_admin>" $config(service_nick)]
        return 0
    }
    if {![string equal $password $config(admin_password)]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Accès refusé."
        ::ClaraServ::FCT::Log:Command "reload refusé" $sender
        return 0
    }
    if {[catch {::ClaraServ::FCT::DB:Reload:Animations} err]} {
        ::ClaraServ::log error "reload admin : $err"
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Reload échoué (état précédent conservé)."
        ::ClaraServ::FCT::Log:Command "reload échec" $sender
        return 0
    }
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Reload des animations terminé."
    ::ClaraServ::FCT::Log:Command "reload ok" $sender
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

proc ::ClaraServ::IRC:CMD:PRIV:CHANFLAG {sender destination command data} {
    variable ::ClaraServ::config

    set channel [lindex $data 0]
    set tag [string tolower [lindex $data 1]]
    set stateRaw [string tolower [lindex $data 2]]
    set password [lindex $data 3]

    if {![::ClaraServ::FCT::Channel:IsValid $channel] \
            || $tag ni {adult vulgar} \
            || $stateRaw ni {on off 0 1}} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender \
            [format "Syntaxe : /msg %s chanflag <#salon> <adult|vulgar> <on|off> \[mdp_admin\]" $config(service_nick)]
        return 0
    }
    set value [expr {$stateRaw in {on 1} ? 1 : 0}]
    if {![::ClaraServ::FCT::Auth:Admin:Or:ChanOp $sender $channel $password]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Accès refusé (admin ou @ du salon requis)."
        ::ClaraServ::FCT::Log:Command "chanflag refusé $channel $tag" $sender
        return 0
    }
    if {[catch {::ClaraServ::FCT::SalonFlags:Set $channel $tag $value} err]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Impossible : $err"
        return 0
    }
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [::ClaraServ::FCT::SalonFlags:Status:Text $channel]
    ::ClaraServ::FCT::Log:Command "chanflag $channel $tag $value" $sender
    return 1
}

proc ::ClaraServ::IRC:CMD:PRIV:CHANFLAGS {sender destination command data} {
    variable ::ClaraServ::config

    set channel [lindex $data 0]
    set password [lindex $data 1]
    if {![::ClaraServ::FCT::Channel:IsValid $channel]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender \
            [format "Syntaxe : /msg %s chanflags <#salon> \[mdp_admin\]" $config(service_nick)]
        return 0
    }
    if {![::ClaraServ::FCT::Auth:Admin:Or:ChanOp $sender $channel $password]} {
        ::ClaraServ::FCT::SENT:MSG:TO:USER $sender "Accès refusé (admin ou @ du salon requis)."
        return 0
    }
    ::ClaraServ::FCT::SENT:MSG:TO:USER $sender [::ClaraServ::FCT::SalonFlags:Status:Text $channel]
    ::ClaraServ::FCT::Log:Command "chanflags $channel" $sender
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
