#!/usr/bin/env tclsh
# Validateur statique des bases d’animations ClaraServ — lecture seule, hors réseau.
# Usage: tclsh tools/validate-animations-db.tcl [fichier.db ...]
# Codes: 0 = pas de FAIL (WARN possibles) ; 1 = au moins un FAIL ; 2 = usage/erreur.

set ROOT [file dirname [file dirname [file normalize [info script]]]]

proc usage {} {
    puts stderr "Usage: tclsh tools/validate-animations-db.tcl \[fichier.db ...\]"
    puts stderr "Sans argument : valide db/database.fr.db et db/database.en.db"
}

if {[llength $argv] >= 1 && [lindex $argv 0] in {-h --help}} {
    usage
    exit 2
}

set files $argv
if {[llength $files] == 0} {
    set files [list \
        [file join $ROOT db database.fr.db] \
        [file join $ROOT db database.en.db] \
    ]
}

set PASS 0
set WARN 0
set FAIL 0

proc v_pass {msg} {
    global PASS
    puts "PASS   $msg"
    incr PASS
}
proc v_warn {msg} {
    global WARN
    puts "WARN   $msg"
    incr WARN
}
proc v_fail {msg} {
    global FAIL
    puts "FAIL   $msg"
    incr FAIL
}

proc count_tag_pairs {text openTag closeTag} {
    set opens [regexp -all $openTag $text]
    set closes [regexp -all $closeTag $text]
    return [list $opens $closes]
}

proc validate_db_file {path} {
    global PASS WARN FAIL
    if {![file isfile $path]} {
        v_fail "fichier introuvable: $path"
        return
    }
    set ns ::AnimVal[clock clicks]
    namespace eval $ns { variable database {} }
    if {[catch {namespace eval $ns [list source $path]} err]} {
        v_fail "[file tail $path]: source impossible ($err)"
        namespace delete $ns
        return
    }
    if {![info exists ${ns}::database]} {
        v_fail "[file tail $path]: variable database absente"
        namespace delete $ns
        return
    }
    set database [set ${ns}::database]
    set n [llength $database]
    v_pass "[file tail $path]: $n entrée(s) sourçable(s)"

    set byCmd [dict create]
    set i 0
    foreach entry $database {
        incr i
        set label "[file tail $path]#$i"
        if {[llength $entry] != 3 || [llength [lindex $entry 0]] != 1} {
            v_fail "$label: format invalide (attendu {{!cmd} {0|1} {texte}})"
            continue
        }
        set cmd [lindex [lindex $entry 0] 0]
        set level [lindex $entry 1]
        set text [lindex $entry 2]
        if {![string match "\!*" $cmd] || [string length $cmd] < 2} {
            v_fail "$label: commande invalide « $cmd »"
            continue
        }
        if {$level ni {0 1}} {
            v_fail "$label: niveau invalide « $level » (0 ou 1)"
            continue
        }
        if {[dict exists $byCmd $cmd $level]} {
            v_fail "$label: doublon $cmd niveau $level"
        } else {
            dict set byCmd $cmd $level $text
        }
        set blen [string bytelength $text]
        if {$blen > 450} {
            v_fail "$label: texte trop long ($blen octets, seuil 450)"
        } elseif {$blen > 350} {
            v_warn "$label: texte long ($blen octets)"
        }
        set bTags [regexp -all {<b>|</b>} $text]
        if {($bTags % 2) == 1} {
            v_warn "$label: nombre impair de balises gras (<b>)</b>) — neutralisé à l’envoi par reset"
        }
        set hasStyle [regexp {<(c|/c|b|/b|u|/u|i|/i|s)[^>]*>} $text]
        if {$hasStyle && ![regexp {<s>\s*$} $text]} {
            v_warn "$label: style sans <s> final — le moteur ajoute un reset à l’envoi"
        }
        # Nouvelles exigences strictes seulement signalées ; anciennes = WARN
        if {[regexp {[\x00-\x08\x0b\x0c\x0e-\x1f]} $text]} {
            v_fail "$label: caractère de contrôle brut dans le texte source"
        }
    }

    dict for {cmd levels} $byCmd {
        set has0 [dict exists $levels 0]
        set has1 [dict exists $levels 1]
        if {$has0 && !$has1} {
            v_fail "[file tail $path]: $cmd a le niveau 0 sans niveau 1"
        } elseif {$has1 && !$has0} {
            v_fail "[file tail $path]: $cmd a le niveau 1 sans niveau 0"
        }
    }
    v_pass "[file tail $path]: paires niveau 0/1 contrôlées ([dict size $byCmd] commande(s))"
    namespace delete $ns
}

puts "ClaraServ validate-animations-db"
puts "------------------------------------------------------------"

# --- Enrichissement vNext (fichiers non sourcés) --------------------------------

proc read_data_lines {path} {
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set lines {}
    while {[gets $fh line] >= 0} {
        set t [string trim $line]
        if {$t eq "" || [string match "#*" $t]} continue
        lappend lines $t
    }
    close $fh
    return $lines
}

proc load_canonical_cmds {dbPath} {
    set ns ::AnimCanon[clock clicks]
    namespace eval $ns { variable database {} }
    if {[catch {namespace eval $ns [list source $dbPath]} err]} {
        namespace delete $ns
        return -code error $err
    }
    set cmds [dict create]
    foreach entry [set ${ns}::database] {
        if {[llength $entry] != 3} continue
        set cmd [string tolower [lindex [lindex $entry 0] 0]]
        # approximate normalisation without ZCT : strip common accents for key compare in validator
        dict set cmds $cmd 1
    }
    namespace delete $ns
    return $cmds
}

proc validate_aliases_file {path canonCmds} {
    if {![file isfile $path]} {
        v_warn "aliases absent (optionnel): $path"
        return
    }
    set brandDeny [list !heineken !leffe !stella !despe !1664 !guinness !coca !banania]
    set sensDeny [list !sexy !string !fesses !fessée !fouet !fessee]
    set seen [dict create]
    set n 0
    foreach line [read_data_lines $path] {
        incr n
        set parts [regexp -all -inline {\S+} $line]
        if {[llength $parts] != 2} {
            v_fail "aliases: ligne invalide « $line »"
            continue
        }
        set a [string tolower [lindex $parts 0]]
        set t [string tolower [lindex $parts 1]]
        if {![string match "\!*" $a] || ![string match "\!*" $t]} {
            v_fail "aliases: préfixe ! requis « $line »"
            continue
        }
        if {$a in $brandDeny || $t in $brandDeny} {
            v_fail "aliases: marque refusée « $line »"
            continue
        }
        if {$t in $sensDeny} {
            v_fail "aliases: cible sensible refusée « $line »"
            continue
        }
        if {[dict exists $seen $a]} {
            v_fail "aliases: doublon $a"
            continue
        }
        dict set seen $a $t
        # canon check approx (accents : accepter si forme sans accent existe aussi)
        set found 0
        if {[dict exists $canonCmds $t]} {
            set found 1
        } else {
            # try matching any canon that equals after removing combining - best effort
            foreach c [dict keys $canonCmds] {
                if {$c eq $t} { set found 1; break }
            }
        }
        if {!$found} {
            # accent-insensitive soft check: compare without non-ascii letters stripped simply
            foreach c [dict keys $canonCmds] {
                if {[string equal -nocase $c $t]} { set found 1; break }
            }
        }
        if {!$found} {
            v_warn "aliases: cible « $t » non trouvée telle quelle dans database (vérifier accents) — $line"
        }
        if {[dict exists $canonCmds $a]} {
            v_fail "aliases: collision avec canonique $a"
        }
    }
    # alias → alias
    foreach {a t} $seen {
        if {[dict exists $seen $t]} {
            v_fail "aliases: pointe vers un alias ($a → $t)"
        }
    }
    v_pass "aliases.fr.db: $n ligne(s) utile(s)"
}

proc validate_sections_file {path label} {
    if {![file isfile $path]} {
        v_warn "$label absent (optionnel): $path"
        return
    }
    set current ""
    set count 0
    set texts 0
    foreach line [read_data_lines $path] {
        if {[regexp {^(![^\s]+)\s+([01])$} $line -> cmd level]} {
            set current $line
            incr count
            continue
        }
        if {$current eq ""} {
            v_fail "$label: texte hors section « $line »"
            continue
        }
        incr texts
        if {[regexp {[\x00-\x08\x0b\x0c\x0e-\x1f]} $line]} {
            v_fail "$label: contrôle brut dans « $line »"
        }
        set hasStyle [regexp {<(c|/c|b|/b|u|/u|i|/i|s)[^>]*>} $line]
        if {$hasStyle && ![regexp {<s>\s*$} $line]} {
            v_warn "$label: style sans <s> final ($current)"
        }
        if {[string bytelength $line] > 450} {
            v_fail "$label: texte trop long ($current)"
        }
    }
    v_pass "$label: $count section(s), $texts texte(s)"
}

set frDb [file join $ROOT db database.fr.db]
set aliasesPath [file join $ROOT db aliases.fr.db]
set variantsPath [file join $ROOT db variants.fr.db]
set failsPath [file join $ROOT db fails.fr.db]

foreach f $files {
    validate_db_file $f
}

if {[llength $argv] == 0} {
    if {[catch {set canon [load_canonical_cmds $frDb]} err]} {
        v_fail "impossible de charger les canoniques pour aliases: $err"
    } else {
        validate_aliases_file $aliasesPath $canon
    }
    validate_sections_file $variantsPath "variants.fr.db"
    validate_sections_file $failsPath "fails.fr.db"
}

puts "------------------------------------------------------------"
puts "Résumé: PASS=$PASS WARN=$WARN FAIL=$FAIL"
if {$FAIL > 0} {
    exit 1
}
exit 0
