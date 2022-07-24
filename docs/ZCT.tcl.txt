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
        "version"		"0.0.1"
        "name"			"package ZCT"
        "auteur"		"ZarTeK-Creole"
    }
}

namespace eval ::ZCT::pkg {
    namespace export *
}
proc ::ZCT::pkg { cmd args } {
    ::ZCT::pkg::${cmd} {*}${args}
}
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
    putlog "${OK_PREFIX} avec la version ${PKG_VERSION} avec succès"
}
proc ::ZCT::pkg::How_Download { PKG_NAME } {
    switch -nocase ${PKG_NAME} {
        Logger { return "Il fait partie de la game de tcllib.\n Téléchargement sur https://www.tcl.tk/software/tcllib/"}
        Tcl { return "Télécharger la derniere version sur https://www.tcl.tk/software/tcltk/"}
        default     {
            return
        }
    }
}

# centre le text par des espaces par rapport a la longueur
proc ::ZCT::TXT:ESPACE:DISPLAY { text length } {
    set text			[string trim $text]
    set text_length		[string length $text];
    set espace_length	[expr ($length - $text_length)/2.0]
    set ESPACE_TMP		[split $espace_length .]
    set ESPACE_ENTIER	[lindex $ESPACE_TMP 0]
    set ESPACE_DECIMAL	[lindex $ESPACE_TMP 1]
    if { $ESPACE_DECIMAL == 0 } {
        set espace_one			[string repeat " " $ESPACE_ENTIER];
        set espace_two			[string repeat " " $ESPACE_ENTIER];
        return "$espace_one$text$espace_two"
    } else {
        set espace_one			[string repeat " " $ESPACE_ENTIER];
        set espace_two			[string repeat " " [expr ($ESPACE_ENTIER+1)]];
        return "$espace_one$text$espace_two"
    }

}

###############################################################################
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
proc ::ZCT::apply_visuals { data } {
    regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} ${data} "\003\\1" data
    regsub -all -nocase {<b>|</b>} ${data} "\002" data
    regsub -all -nocase {<u>|</u>} ${data} "\037" data
    regsub -all -nocase {<i>|</i>} ${data} "\026" data
    return [regsub -all -nocase {<s>} $data "\017"]
}
proc ::ZCT::Remove_visuals { data } {
    regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} ${data} "" data
    regsub -all -nocase {<b>|</b>} ${data} "" data
    regsub -all -nocase {<u>|</u>} ${data} "" data
    regsub -all -nocase {<i>|</i>} ${data} "" data
    return [regsub -all -nocase {<s>} ${data} ""]
}


package provide ZCT ${::ZCT::PKG(version)}
putlog "Package ZCT version ${::ZCT::PKG(version)} par ${::ZCT::PKG(auteur)} chargé."