# Tcl package index file, version 1.1
# Aligné manuellement (Lot 0 — vendorisation ClaraServ) sur package provide IRCServices 0.1.0.
# Le runtime ClaraServ charge IRCServices via « source » relatif ; cet index n’est pas
# requis au démarrage, mais doit rester cohérent pour portabilité / auto_path local futur.
# Ne pas régénérer aveuglément avec pkg_mkIndex sans vérifier PKG(version).

package ifneeded IRCServices 0.1.0 [list source [file join ${dir} ircservices.tcl]]
