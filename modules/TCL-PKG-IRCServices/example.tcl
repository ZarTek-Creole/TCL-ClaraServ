#!/usr/bin/tclsh
package require IRCServices

set CONNECT_ID [::IRCServices::connection]; # Creer une instance services
$CONNECT_ID connect 127.0.0.1 +7002 passwordlink 1 eva.info 00C
set BOT_ID [$CONNECT_ID bot]; #Creer une instance bot dans linstance services
$BOT_ID create ClaraServ services ClaraServ.eggdrop.fr "Visit: https://git.io/JYY9b" +Soiq
$BOT_ID join #Services
$BOT_ID registerevent PRIVMSG {
       set cmd         [lindex [msg] 0]
       set data        [lrange [msg] 1 end]
       ##########################
       #--> Commandes Privés <--#
       ##########################
       # si [target] ne commence pas par # c'est un pseudo
       if { [string index [target] 0] != "#"} {
               if { $cmd == "help"             }       { 
                       puts "PRIV: [who2] [target2] $cmd $data"
               }
       }
       ##########################
       #--> Commandes Salons <--#
       ##########################
       # si [target] commence par # c'est un salon
       if { [string index [target] 0] == "#"} {
               if { $cmd == "!help"    }       { 
                       puts "PUB: [who] [target] $cmd $data"
               }
       }
}; # Creer un event sur PRIVMSG
vwait state