#############################################################################
#
#	Auteur	:
#		-> ZarTek (ZarTek.Creole@GMail.Com)
#
#	Website	:
#		-> github.com/ZarTek-Creole/TCL-ZCT
#
#	Support	:
#		-> github.com/ZarTek-Creole/TCL-ZCT/issues
#
#	Docs	:
#		-> github.com/ZarTek-Creole/TCL-ZCT/wiki
#
#   DONATE   :
#       -> https://github.com/ZarTek-Creole/DONATE
#
#	LICENSE :
#		-> Creative Commons Attribution 4.0 International
#		-> github.com/ZarTek-Creole/TCL-ZCT/blob/main/LICENSE.txt
#
#
#############################################################################
namespace eval ::ZCT {
    namespace export *
    variable PKG
    array set PKG {
        "version"		"0.0.9"
        "name"			"package ZCT"
        "auteur"		"ZarTeK-Creole @ https://github.com/ZarTek-Creole"
    }
    if { [info commands ::putlog] == "" } {
        set ::ZCT::eggdrop 0
        set ::ZCT::PPL "puts"
    } else {
        set ::ZCT::eggdrop 1
        set ::ZCT::PPL "putlog"
    }
}

namespace eval ::ZCT::pkg {
}
# Chargeur de package en cas d'absence de celui-ci 
# il indique comment le télécharger
#
# @param PKG_NAME Le nom exact du packages (obligatoire)
# @param PKG_VERSION La version minimal que le packages doit charger
# @param SCRIPT_NAME Le nom de votre script dans le quel vous voulez charger le package
# @param MISSING_MODE Comment afficher les erreur ? putlog, puts, die(par default) ?
# @return Le status charger ou erreur
proc ::ZCT::pkg::load { PKG_NAME {PKG_VERSION ""} {SCRIPT_NAME ""} {MISSING_MODE "die"} } {
    if { ${SCRIPT_NAME} == "" }  {
        set ERR_PREFIX "\[Erreur\] Le script nécessite du package '${PKG_NAME}'"
        set OK_PREFIX "\[OK\] Le script à chargé le package '${PKG_NAME}'"
    } else {
        set ERR_PREFIX "\[Erreur\] Le script '${SCRIPT_NAME}' nécessite du package '${PKG_NAME}'"
        set OK_PREFIX "\[OK\] Le script '${SCRIPT_NAME}' à chargé le package '${PKG_NAME}'"
    }
    if { ${PKG_VERSION} == "" } {
        if { [catch { set PKG_VERSION [package require ${PKG_NAME}]}] } {
            ${MISSING_MODE} "${ERR_PREFIX} pour fonctionner. [::ZCT::pkg::How_Download ${PKG_NAME}]"
        }
    } else {
        if { [catch { set PKG_VERSION [package require ${PKG_NAME} ${PKG_VERSION}]}] } {
            ${MISSING_MODE} "${ERR_PREFIX} version ${PKG_VERSION} ou supérieur pour fonctionner. [::ZCT::pkg::How_Download ${PKG_NAME}]"
        }
    }
    ${::ZCT::PPL} "${OK_PREFIX} avec la version ${PKG_VERSION} avec succès"
}
# Si un package est absent lors du "pkg load" nous retournons une aide pour l'installer le package manquant
proc ::ZCT::pkg::How_Download { PKG_NAME } {
    switch -nocase ${PKG_NAME} {
        Logger      	{ return "Il fait partie de la game de tcllib.\n Téléchargement sur https://www.tcl.tk/software/tcllib/" }
        IRCServices  	{ return "Télécharger la derniere version sur https://github.com/ZarTek-Creole/TCL-PKG-IRCServices" }
        Tcl         	{ return "Télécharger la derniere version sur https://www.tcl.tk/software/tcltk/" }
        default     	{ return "Aucune information sur ${PKG_NAME}, vous devez chercher sur internet"   }
    }
}
# Verifications de presence de variables.
# Utile pour verifié que tout les variables ont bien été donné dans une fichier de configuration
# dans
# set VARS_LIST				[list "list1" "list2"];  #definitié les nom des arrayx
#  Le code verifie a partir de la les listes defini graces a
# set VARS_list1			[list "var1" "var2"]
# set VARS_list2			[list "var3" "var4"]
# Il verifiera la presence de ${list1(var1)}, ${list1(var2)}, ${list2(var3)} et ${list2(var4)}
#
# @param NAMESPACE Le nom de l'espace nom dans le quel rechercher
# @return NULL
proc ::ZCT::Is:ArrayList:Exists { NAMESPACE } {
    set ::TMP_NS_ArrayList ${NAMESPACE}
    namespace inscope ${NAMESPACE} {
        variable VARS_LIST
        if { ![info exists VARS_LIST] } {
            return -code error \
                [format "%s > La liste des ArrayLists a verifier '%s' est inexistant." ${::TMP_NS_ArrayList} "VARS_LIST"]
        }
        foreach LIST_NAME ${VARS_LIST} {
            puts [format "%s > Verification de la présence des variables : \$%s\(..)" ${::TMP_NS_ArrayList} ${LIST_NAME}]
            variable VARS_${LIST_NAME}
            if { ![info exists VARS_${LIST_NAME}] } {
                return -code error \
                    [format "%s > Liste de variables '%s' est inexistant." ${::TMP_NS_ArrayList} "VARS_${LIST_NAME}"]
            }
            variable ${LIST_NAME}
            if { ![array exists ${LIST_NAME}] } {
                return -code error \
                    [format "%s > '%s' n'est pas une liste Array." ${::TMP_NS_ArrayList} "${LIST_NAME}"]
            }
            foreach VAR_NAME [subst \$VARS_${LIST_NAME}] {
                if { ![info exists ${LIST_NAME}(${VAR_NAME})] } {
                    return -code error \
                        [format "%s > L'Array '%s' est inexistant." ${::TMP_NS_ArrayList} "${LIST_NAME}(${VAR_NAME})"]
                }
            }
        }
        unset  ::TMP_NS_ArrayList
    }

}
# Creer des couleurs pour le partyline
# par exemple pour du TEXT en rouge en partyline :
# putlog "[pcolor_red]mon text rouge[pcolors_end] et ici aucune couleur"
foreach {color_name value} { red 1 yellow 3 cyan 5 magenta 6 blue 4 green 2 } {
    proc ::ZCT::pcolor_${color_name} {} "return \033\\\[01\\;3${value}m"
}
proc ::ZCT::pcolors_end { } {
    return \033\[\;0m
}
# procedure qui retourne où il est appellé
proc ::ZCT::calledby {} {
    set level [expr [info leve] - 2]
    if { ${level} > 0 } {
        return [lindex [info level ${level} ] 0]
    } else {
        if { [string length [info script] ] > 0 } {
            return [info script]
        } else {
            return [info nameofexecutable]
        }
    }
}
# Putlog amelioreé, avec des niveau (couleurs differentes) et type de text
if { ${::ZCT::eggdrop} } {
    proc ::ZCT::putlog { text {level_name ""} {text_name ""} } {
        variable ::ZCT::SCRIPT
        set UP_LEVEL_NAME [::ZCT::calledby]
        if { ${text_name} == "" } {
            if { ${level_name} != "" } {
                set text_name " - ${level_name}"
            } else {
                set text_name ""
            }
        } else {
            set text_name " - ${text_name}"
        }
        switch -nocase ${level_name} {
            "error"		{ puts "[pcolor_red]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
            "warning"	{ puts "[pcolor_yellow]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
            "notice"	{ puts "[pcolor_cyan]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
            "debug"		{ puts "[pcolor_magenta]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
            "info"		{ puts "[pcolor_blue]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
            "success"	{ puts "[pcolor_green]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
            default		{ puts "\[${UP_LEVEL_NAME}${text_name}\] [pcolor_blue]${text}[pcolors_end]" }
        }
    }
    if { [info commands ::putlog.old] == "" } {
        rename ::putlog ::putlog.old;
        interp alias {} putlog {} ::ZCT::putlog
    }
}
# Procedure interne qui permet de creer les procs et les subprocs automatiquement
# https://forum.eggdrop.fr/Une-proc-qui-gere-lexploration-des-sous-commandes-par-les-namespaces-t-1951.html
#
# @param namespace Le nom d'espacement a suivre
# @return NULL - Cree des (SUB-)PROCS
proc ::ZCT::create_sub_procs { namespace } {
    # Boucle sur les namespaces enfants de $namespace (::example) retourne -> ::example::text; ::example::text2
    foreach child_name [namespace children ${namespace}] {
        # Création de procédure portant le nom des namespaces enfants ::example::text, ::example::text2
        proc ${child_name} { {subcommand ""} args } {
            # tout ce qui fais partie ici, sera exécuté lors de l'exécution de la proc créer
            # les variables, commandes
            # le  proc_path contient chemin de la proc (lors de sont exécution et non maintenant donc)
            set proc_path [lindex [info level 0] 0]
            # Si la proc est appeler sans subcommand, nous signalons qu'elle nécessite une
            if { ${subcommand} == "" } {
                return  -code error \
                    "wrong # args: should be \"${proc_path} subcommand ?arg ...?\""
            }
            # Si la subcommand n'existe pas dans les procs enfants, ont prévois de retourner la liste des procs existante dans le namespace courant (celle de la proc appelé )
            if { [info commands ${proc_path}::${subcommand}] == "" } {
                set subcommands_list  [join [string map "${proc_path}:: \"\"" [info procs ${proc_path}::*]] ", "]
                return  -code error \
                    "wrong ${proc_path} unknown or ambiguous subcommand \"${subcommand}\": must be ${subcommands_list}"
            }
            # si la subcommand existe, on l'execute avec les valeurs fournis
            ${proc_path}::${subcommand} {*}${args}
        }
        # ici nous sommes sorties de la création de la proc, et de retour dans la boucle enfant, nous allons exporté les proc
        namespace export *
        # Nous allons répéter ces opérations dans le niveau inferieur/enfants (dans ::example::text et ::example::text2)
        create_sub_procs ${child_name}
    }
    # fin de la boucle
}
namespace eval ::ZCT::TXT {
    namespace export *
}
namespace eval ::ZCT::TXT::visuals {
    namespace export *
}
# Supprimer les accents dans une chaîne de caractères
# Utile par exemple pour effectuer une recherche de TEXT en ne tenant pas compte des caractères accentués.
# source : https://boulets.eggdrop.fr/tcl/routines/tcl-toolbox-0011.html
#
# @param TEXT Le TEXT dont les accents doivent être enlever
# @return Le TEXT sans accents, ni cédiles
proc ::ZCT::TXT::remove_accents { TEXT } {
	return [::tcl::string::map -nocase {
		"à" "a" "â" "a" "ä" "a" "ã" "a" "å" "a" "á" "a" "à" "a" "å" "a"
		"é" "e" "è" "e" "ê" "e" "ë" "e"
		"î" "i" "ï" "i" "î" "i" "í" "i" "ì" "i"
		"ô" "o" "ö" "o" "õ" "o" "ø" "o" "ò" "o" "ó" "o"
		"ù" "u" "û" "u" "ü" "u" "ú" "u"
		"ý" "y" "ÿ" "y"
		"ç" "c" "ð" "d" "ñ" "n" "š" "s" "ž" "z"
	} ${TEXT}]
}

# Supprimer les accents dans une chaîne de caractères
# Utile par exemple pour effectuer une recherche de TEXT en ne tenant pas compte des caractères accentués.
# source : https://boulets.eggdrop.fr/tcl/routines/tcl-toolbox-0011.html
#
# @param TEXT Le TEXT contenant des variables de subtitutions
# @param Channel Le salon pour remplacer %chan% (facultatif)
# @return Le TEXT avec les doonées de subtitutions replacer
proc ::ZCT::TXT::REPLACE_SUBSTITUTE { TEXT {Channel ""} } {
	regsub -all %chan%			${TEXT} ${Channel} TEXT;
	regsub -all %botnick%		${TEXT} [regsub -all {\W} ${::ClaraServ::config(service_nick)} {\\&}] TEXT;
	regsub -all %hour%			${TEXT} [set hour [strftime %H [unixtime]]] TEXT;
	regsub -all %hour_short%	${TEXT} [if { ${hour} != 00 } { set dummy [string trimleft ${hour} 0] } { set dummy 0 }] TEXT;
	regsub -all %minutes%		${TEXT} [set minutes [strftime %M [unixtime]]] TEXT;
	regsub -all %minutes_short%	${TEXT} [if { ${minutes} != 00 } { set dummy [string trimleft ${minutes} 0] } { set dummy 0 }] TEXT;
	regsub -all %seconds%		${TEXT} [set seconds [strftime %S [unixtime]]] TEXT;
	regsub -all %seconds_short%	${TEXT} [if { ${seconds} != 00 } { set dummy [string trimleft ${seconds} 0] } { set dummy 0 }] TEXT;
	regsub -all %day_num%		${TEXT} [strftime %d [unixtime]] TEXT;
	regsub -all %day%			${TEXT} [string map -nocase {Mon lundi Tue mardi Wed mercredi Thu jeudi Fri vendredi Sat samedi Sun dimanche} [strftime "%a" [unixtime]]] TEXT;
	regsub -all %month_num%		${TEXT} [strftime %m [unixtime]] TEXT;
	regsub -all %month%			${TEXT} [string map {Jan janvier Feb février Mar mars Apr avril May mai Jun juin Jul juillet Aou août Sep septembre Oct octobre Nov novembre Dec décembre} [strftime %b [unixtime]]] TEXT;
	regsub -all %year%			${TEXT} [strftime %Y [unixtime]] TEXT;
	return ${TEXT}
}

# Centrer un TEXT avec des espaces sur une longueur donnée
#
# @param TEXT Le TEXT qui doit être centré
# @param LENGTH La longueur voulu avec les espacements
# @return Le TEXT centré avec le nombre d'espaces pour avoir une longueur égal à LENGTH
proc ::ZCT::TXT::visuals::espace { TEXT LENGTH } {
    set text			[string trim ${TEXT}]
    set text_length		[string length ${TEXT}];
    set espace_length	[expr (${LENGTH} - ${text_length})/2.0]
    set ESPACE_TMP		[split ${espace_length} .]
    set ESPACE_ENTIER	[lindex ${ESPACE_TMP} 0]
    set ESPACE_DECIMAL	[lindex ${ESPACE_TMP} 1]
    if { ${ESPACE_DECIMAL} == 0 } {
        set espace_one			[string repeat " " ${ESPACE_ENTIER}];
        set espace_two			[string repeat " " ${ESPACE_ENTIER}];
        return "${espace_one}${TEXT}${espace_two}"
    } else {
        set espace_one			[string repeat " " ${ESPACE_ENTIER}];
        set espace_two			[string repeat " " [expr (${ESPACE_ENTIER}+1)]];
        return "${espace_one}${TEXT}${espace_two}"
    }
}

# Enleve les style visuals
#
# @param TEXT Le TEXT avec des codes style
# @return Le TEXT sans les codes styles
proc ::ZCT::TXT::visuals::remove { TEXT } {
    regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} ${TEXT} {} TEXT;
    regsub -all -nocase {<b>|</b>} ${TEXT} {} TEXT;
    regsub -all -nocase {<u>|</u>} ${TEXT} {} TEXT;
    regsub -all -nocase {<i>|</i>} ${TEXT} {} TEXT;
    return [regsub -all -nocase {<s>} ${TEXT} {}];
}

##############################################################################
### Substitution des symboles couleur/gras/soulignement/...
###############################################################################
# Modification de la fonction de MenzAgitat
# <cXX> : Ajouter un Couleur avec le code XX : <c01>; <c02,01>
# </c>  : Enlever la Couleur (refermer la deniere declaration <cXX>) : </c>
# <b>   : Ajouter le style Bold/gras
# </b>  : Enlever le style Bold/gras
# <u>   : Ajouter le style Underline/souligner
# </u>  : Enlever le style Underline/souligner
# <i>   : Ajouter le style Italic/Italique
# <s>   : Enlever les styles precedent
##
# Noir        /  Black       = 00
# Blanc       /  White       = 01
# Bleu foncé  /  Dark Blue   = 02
# Vert        /  Green       = 03
# Rouge       /  Red         = 04
# Marron      /  Brown       = 05
# Violet      /  Purple      = 06
# Orange      /  Orange      = 07
# Jaune       /  Yellow      = 08
# Vert clair  /  Light Green = 09
# Cyan foncé  /  Dark Cyan   = 10
# Cyan clair  /  Light Cyan  = 11
# Bleu clair  /  Light Blue  = 12
# Rose        /  Pink        = 13
# Gris foncé  /  Dark Grey   = 14
# Gris clair  /  Light Grey  = 15
##
# @param TEXT Le TEXT avec des codes style a remplacer avec de vrai codes styles (couleurs, gras..)
# @return Le TEXT avec les codes styles en TCl
proc ::ZCT::TXT::visuals::apply { TEXT } {
    regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} ${TEXT} "\003\\1" TEXT;
    regsub -all -nocase {<b>|</b>} ${TEXT} "\002" TEXT;
    regsub -all -nocase {<u>|</u>} ${TEXT} "\037" TEXT;
    regsub -all -nocase {<i>|</i>} ${TEXT} "\026" TEXT;
    return [regsub -all -nocase {<s>} ${TEXT} "\017"];
}

::ZCT::create_sub_procs ::ZCT

package provide ZCT ${::ZCT::PKG(version)}
${::ZCT::PPL} "Package ZCT version ${::ZCT::PKG(version)} par ${::ZCT::PKG(auteur)} chargé."