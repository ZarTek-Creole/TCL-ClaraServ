#!/usr/bin/tclsh

# ====================================================================== 
# Configurable items
# ====================================================================== 

# Install dir: ${destLib}/${packagename} 
set destLib [file join /usr/lib/tcltk]
set packageName IRCServices

# List of source/dest to install
set filesList {
	pkgIndex.tcl
	ircservices.tcl
}


# ====================================================================== 
# Determine the destination lib dir
# ====================================================================== 
if {[llength ${::argv}] == 1} {
	set destLib [lindex ${::argv} 0]
}
if {[lsearch ${auto_path} ${destLib}] == -1} {
	puts "ERROR: Invalid directory to install. Must be one of these:"
	puts "[join ${auto_path} \n]"
	exit 1
}

set destLib [file join ${destLib} ${packageName}]
file mkdir ${destLib}

# ====================================================================== 
# Install
# ====================================================================== 

foreach source ${filesList} {
	set dest [file join ${destLib} ${source}]
	puts "Installing ${dest}"

	# Create destination dir if needed
	set destDir [file dirname ${dest}]
	if {![file isdirectory ${destDir}]} { file mkdir ${destDir} }

	# Copy
	file copy ${source} ${dest}
}

puts "Done"