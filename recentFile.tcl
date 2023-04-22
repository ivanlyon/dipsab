###############################################################################
# recentFile -- TCL class to manage list of recent files.
#
#               To use this file, modify TK app in a few ways:
#               1. source recentFile.tcl
#               2. RecentFile create <variableName> <fileName> <count>
#               3. As needed: "update" with file name when encountered
#               4. Query: "all" for current time ordered list of recent names
#
################################################################################
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
###############################################################################
oo::class create RecentFiles {
    variable FileNames ConfigFile Capacity
    constructor {configFilename capacity} {
        set FileNames {}
        set ConfigFile $configFilename
        set Capacity $capacity
        if {[file isfile $ConfigFile]} {
            set fp [open $ConfigFile r]
                set FileNames [split [read $fp] \n]
            close $fp
            my TrimList
        }
        return
    }

    # Remove existing appearance of file name then insert it into 1st place
    method update {mostRecent} {
        set index [lsearch -exact $FileNames $mostRecent]
        set FileNames [lreplace $FileNames $index $index]
        set FileNames [linsert $FileNames 0 $mostRecent]
        my TrimList
        set fp [open $ConfigFile w]
            foreach rf $FileNames {
                puts $fp $rf
            }
        close $fp
        return
    }

    # Remove all blank file names then cull excess file names
    method TrimList {} {
        set FileNames [lsearch -all -inline -not -exact $FileNames {}]
        while {[llength $FileNames] >= $Capacity} {
            set FileNames [lreplace $FileNames end end]
        }
        return
    }

    # Provided to conveniently load most recent file at application start
    method top {} {
        lindex $FileNames 0
    }

    method all {} {
        return $FileNames
    }
}
