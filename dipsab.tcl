#!/bin/sh
# TCL ignores the next line -*- tcl -*- \
exec wish "$0" -- "$@"

###############################################################################
# DIPSAB -- Directory Images Padded, Stacked and Bordered
#           Create wallpaper images composed of other images organized into
#           directories.
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
package require md5
package require jpeg
package require json
source recentFile.tcl

dict set defaultProps bgColor #000000
dict set defaultProps border 40
dict set defaultProps width 1920
dict set defaultProps height 1080
dict set defaultProps header 0
dict set defaultProps footer 0
dict set defaultProps caseSensitive 0
dict set defaultProps disArticles 0

set configFilename ""
set cfg [dict create]
dict set cfg props [dict create {*}$defaultProps]
dict set cfg layer [dict create]
dict set cfg md5cat 0
dict set cfg export ""
dict set cfg xSize 0
dict set cfg ySize 0
dict set cfg previewing false
RecentFiles create RF .dipsab 3
set convenience 0

menu .m -tearoff 0
menu .m.file -tearoff 0
.m add cascade -label "File" -menu .m.file -underline 0
    .m.file add command -label "New" -command {newCommand}
    .m.file add command -label "Open..." -command {LoadConfig}
    .m.file add cascade -label "Recent Files" -menu [menu .m.file.rf -tearoff 0] -state disabled
    .m.file add command -label "Save" -command {SaveConfig false}
    .m.file add command -label "Save As..." -command {SaveConfig}
    .m.file add separator
    .m.file add command -label "Properties" -command {ConfigProperties}
    .m.file add command -label "Export" -command {ExportImage false}
    .m.file add command -label "Export As..." -command {ExportImage}
    .m.file add separator
    .m.file add command -label "Exit" -command {destroy .}
. configure -menu .m

set layerBG "#999"
frame .ftb -padx 3 -pady 3 -relief groove -borderwidth 1 -background $layerBG
pack .ftb -side top -expand no -fill x -anchor n
    label .ftb.lbl -text "Layer commands: " -background $layerBG
    button .ftb.add -text "\u271A" -command {AddLayer "" 0 0 true}
    button .ftb.rem -text "\u2796" -state disabled -command {RemoveLayer}
    button .ftb.raise -text "\u2963" -state disabled -command {RaiseLayer}
    button .ftb.lower -text "\u2965" -state disabled -command {LowerLayer}
    pack .ftb.lbl .ftb.add .ftb.rem .ftb.raise .ftb.lower -side left -padx 4

label .statusbar -relief sunken -borderwidth 2 -anchor w
pack .statusbar -side bottom -fill x

frame .ftl -padx 3 -pady 3 -background $layerBG
pack .ftl -side left -expand yes -fill y -anchor nw
    labelframe .ftl.lf -text "Strata" -background $layerBG
    pack .ftl.lf -side top -expand yes -fill both

frame .fi -background red
pack .fi -side left -expand yes -fill both
    label .fi.ci -image ""
    pack .fi.ci -expand yes -fill both

wm geometry . 800x600
wm title . "dipsab"
update

#----------------------------------------------------------------------------
# ExportImage --
#
#     Save the computed image to PNG file.
#
# Arguments:
#     novel (optional) - true when performing "Export As" file selection.
# Results:
#     Image file is saved.
#----------------------------------------------------------------------------
proc ExportImage {{novel true}} {
    global cfg
    if {$novel || ([dict get $cfg export] == "")} {
        set types {
            {{PNG}       {.png}}
            {{All Files}  *    }
        }
        if {[dict get $cfg export] != ""} {
            set initName [dict get $cfg export]
            set f [tk_getSaveFile -filetypes $types -initialfile [file tail $initName] -initialdir [file dirname $initName]]
        } else {
            set f [tk_getSaveFile -filetypes $types]
        }
        dict set cfg export $f
    }
    if {[dict get $cfg export] != ""} {
        [dict get $cfg img] write [dict get $cfg export] -format PNG
        SetStatus [format "Image exported: %s" [dict get $cfg export]]
    }
    return
}

#----------------------------------------------------------------------------
# Dict2JSON --
#
#     Recursive proc to create json compatible struction from dict. Note the
#     use of reserved text words to selectively prevent recursion.
#
# Arguments:
#     theDict - dictionary to be converted
#     reserved - list of text items ending recursion
#     indent (optional) - number of indentations, accumulates with depth
# Results:
#     List of strings containing json format of dict.
#----------------------------------------------------------------------------
proc Dict2JSON {theDict reserved {indent 0}} {
    set result ""
    if {$indent == 0} {
        append result "\{"
    }
    incr indent
    set spaces [string repeat " " [expr {4 * $indent}]]

    set eol "\n"
    foreach {key val} $theDict {
        if {[lsearch -exact $reserved $key] >= 0} {
            # "reserved" means list is plain text rather than serialized dict
            append result [format "%s%s\"%s\": \"%s\"" $eol $spaces $key $val]
        } elseif {[expr {![catch {dict size $val}]}]} {
            # Test isDict (Above boolean) is passed
            append result [format "%s%s\"%s\": \{" $eol $spaces $key]
            append result [Dict2JSON $val $reserved $indent]
            append result [format "\n%s\}" $spaces]
        } else {
            append result [format "%s%s\"%s\": \"%s\"" $eol $spaces $key $val]
        }
        set eol ",\n"
    }

    incr indent -1
    if {$indent == 0} {
        append result "\n\}"
    }
    return $result
}

#----------------------------------------------------------------------------
# SetConfigFilename --
#
#     Assign and display the global variable configFilename.
#
# Arguments:
#     newname - new name of configuration file.
# Results:
#     Global variable assigned and window title renamed.
#----------------------------------------------------------------------------
proc SetConfigFilename {newname} {
    global configFilename
    set configFilename $newname
    wm title . [format "%s - DIPSAB" [file tail $newname]]
    return
}

#----------------------------------------------------------------------------
# SaveConfig --
#
#     Assign and display the global variable configFilename.
#
# Arguments:
#     novel (optional) - true when performing "Save As" file selection.
# Results:
#     Global variable assigned and window title renamed.
#----------------------------------------------------------------------------
proc SaveConfig {{novel true}} {
    global configFilename cfg

    if {$novel || ($configFilename == "")} {
        set types {
            {{DIPSAB configuration files} {.json}}
            {{All Files}                   *     }
        }
        if {$configFilename ne ""} {
            set saving [tk_getSaveFile -filetypes $types -initialfile [file tail $configFilename] -initialdir [file dirname $configFilename]]
        } else {
            set saving [tk_getSaveFile -filetypes $types]
        }
        SetConfigFilename $saving
    }
    if {$configFilename != ""} {
        set reserved {bgColor directory export}
        set tmp [dict get $cfg img]
        dict set cfg img 0
        set fp [open $configFilename w]
            puts $fp [Dict2JSON $cfg $reserved]
        close $fp
        dict set cfg img $tmp
        UpdateRecentFiles $configFilename
        SetStatus [format "Configuration saved: %s" $configFilename]
    }
    return
}

#----------------------------------------------------------------------------
# LoadConfig --
#
#     Load a configuration file and create the image.
#
# Results:
#     Image is displayed and ready for export.
#----------------------------------------------------------------------------
proc LoadConfig {{loading ""}} {
    global configFilename cfg
    if {$loading eq ""} {
        set types {
            {{DIPSAB configuration files} {.json}}
            {{All Files}                  *      }
        }
        if {$configFilename ne ""} {
            set loading [tk_getOpenFile -filetypes $types -initialfile [file tail $configFilename] -initialdir [file dirname $configFilename]]
        } else {
            set loading [tk_getOpenFile -filetypes $types]
        }
    }
    if {$loading ne ""} {
        RemoveAllLayers
        SetConfigFilename $loading
        set fp [open $configFilename r]
            set cfg [::json::json2dict [read $fp]]
        close $fp

        set buffer [dict get $cfg layer]
        dict set cfg layer [dict create]
        set slayers [dict size $buffer]
        for {set i 1} {$i <= $slayers} {incr i} {
            AddLayer [dict get $buffer $i directory] \
                     [dict get $buffer $i hPad] \
                     [dict get $buffer $i vPad]
        }
        unset buffer
        dict set cfg previewing false
        UpdateRecentFiles $loading
    }
    return
}

#----------------------------------------------------------------------------
# SetThenLoadConfig --
#
#     Save global configuration file name variable the load it.
#
# Results:
#     Newly assigned configuration file is loaded.
#----------------------------------------------------------------------------
proc SetThenLoadConfig {newFileName} {
    SetConfigFilename $newFileName
    LoadConfig $newFileName
    return
}

#----------------------------------------------------------------------------
# UpdateRecentFiles --
#
#     Load the recent files menu with current list.
#
# Results:
#     Recent files menu shows most recent list.
#----------------------------------------------------------------------------
proc UpdateRecentFiles {{mostRecent ""}} {
    global RF
    RF update $mostRecent
    if {[RF top] ne ""} {
        .m.file entryconfigure "Recent Files" -state normal
        .m.file.rf delete 0 end
        foreach rFilename [RF all] {
            .m.file.rf add command -label $rFilename -command [list SetThenLoadConfig $rFilename]
        }
    }
    return
}

#----------------------------------------------------------------------------
# AddLayer --
#
#     Add a layer to the image composed if its directory and padding values.
#     Add a button to the GUI to access layer configuration.
#
# Arguments:
#     dir - the directory from which images will be copied.
#     pad1 - pixels of horizontal padding images in the directory
#     pad2 - pixels of vertical padding images in the directory
#     configure (optional) - true when performing "Save As" file selection.
# Results:
#     A row of the DIPSAB image is added to the bottom.
#----------------------------------------------------------------------------
proc AddLayer {dir pad1 pad2 {configure false}} {
    global cfg
    set adding [expr {1 + [dict size [dict get $cfg layer]]}]
    dict set cfg layer $adding directory $dir
    dict set cfg layer $adding hPad $pad1
    dict set cfg layer $adding vPad $pad2
    dict set cfg layer $adding count 0
    button .ftl.lf.b$adding -text $adding
    bind .ftl.lf.b$adding <ButtonRelease-1> {ConfigLayer %W}
    pack .ftl.lf.b$adding -side top -padx 2 -pady 2 -fill x
    if {$configure} {
        ConfigLayer .ftl.lf.b$adding
    }
    .ftb.rem configure -state normal
    if {$adding > 1} {
        .ftb.raise configure -state normal
        .ftb.lower configure -state normal
    }
    return
}

#----------------------------------------------------------------------------
# SwapLayers --
#
#     Swap 2 dictionary elements given constant top level keys.
#
# Arguments:
#     num1 - number of one layer to be exchanged.
#     num2 - number of other layer to be exchanged.
# Results:
#     The list of layers is modified and the image is rendered accordingly.
#----------------------------------------------------------------------------
proc SwapLayers {num1 num2} {
    global cfg
    foreach key [dict keys [dict get $cfg layer 1]] {
        set tmp [dict get $cfg layer $num2 $key]
        dict set cfg layer $num2 $key [dict get $cfg layer $num1 $key]
        dict set cfg layer $num1 $key $tmp
    }
    return
}

#----------------------------------------------------------------------------
# RaiseLayer --
#
#     Exchange a layer with the preceding layer.
#
# Results:
#     The list of layers is modified.
#----------------------------------------------------------------------------
proc RaiseLayer {} {
    global cfg
    set layers [dict size [dict get $cfg layer]]
    if {$layers > 1} {
        set number [RangedIntDlg "Choose layer to raise one level" 2 $layers]
        if {$number > 0} {
            SwapLayers $number [expr {$number - 1}]
        }
    }
    return
}

#----------------------------------------------------------------------------
# LowerLayer --
#
#     Exchange a layer with the following layer.
#
# Results:
#     The list of layers is modified.
#----------------------------------------------------------------------------
proc LowerLayer {} {
    global cfg
    set layers [dict size [dict get $cfg layer]]
    if {$layers > 1} {
        set number [RangedIntDlg "Choose layer to lower one level" 1 [expr {$layers - 1}]]
        if {$number > 0} {
            SwapLayers $number [expr {$number + 1}]
        }
    }
    return
}

#----------------------------------------------------------------------------
# RemoveLayer --
#
#     Remove a layer from the list of layers and create the resulting image.
#
# Results:
#     The list of layers is modified.
#----------------------------------------------------------------------------
proc RemoveLayer {} {
    global cfg
    set layers [dict size [dict get $cfg layer]]
    if {$layers > 0} {
        set number [RangedIntDlg "Choose layer to remove" 1 $layers]
        if {$number > 0} {
            for {set i $number} {$i < $layers} {incr i} {
                foreach key [dict keys [dict get $cfg layer $i]] {
                    dict set cfg layer $i $key [dict get $cfg layer [expr {$i + 1}] $key]
                }
            }
            dict unset cfg layer $layers
            destroy .ftl.lf.b$layers

            if {$layers < 3} {
                .ftb.raise configure -state disabled
                .ftb.lower configure -state disabled
                if {$layers < 2} {
                    .ftb.rem configure -state disabled
                }
            }
        }
    }
    return
}

#----------------------------------------------------------------------------
# RemoveAllLayers --
#
#     Properly delete all existing layers from the session configuration.
#
# Results:
#     The list of layers set to an empty dictionary.
#----------------------------------------------------------------------------
proc RemoveAllLayers {} {
    global cfg
    set layers [dict size [dict get $cfg layer]]
    for {set i 1} {$i <= $layers} {incr i} {
        destroy .ftl.lf.b$i
    }
    dict set cfg layer [dict create]
    return
}

#----------------------------------------------------------------------------
# GriddedSpinBox --
#
#     Add a spin box to a widget per spec.
#
# Arguments:
#     parent - widget maintaining the grid for the new spinbox
#     rowNum - grid row number
#     legend - text description of the spinbox
#     lo - the lowest value of the spin box range
#     hi - the highest value of the spin box range
# Results:
#     The spin box widget ID is returned.
#----------------------------------------------------------------------------
proc GriddedSpinBox {parent rowNum legend lo hi} {
    global convenience

    label $parent.$convenience -text $legend
    grid $parent.$convenience -row $rowNum -column 0 -sticky e
    incr convenience

    spinbox $parent.$convenience -from $lo -to $hi
    grid $parent.$convenience -row $rowNum -column 1 -columnspan 2 -sticky news
    set widgetOfInterest $parent.$convenience
    incr convenience

    return $widgetOfInterest
}

#----------------------------------------------------------------------------
# GriddedCheckBox --
#
#     Add a check box to a widget per spec.
#
# Arguments:
#     parent - widget maintaining the grid for the new checkbox
#     rowNum - grid row number
#     legend - text description of the checkbox purpose
#     subtext - text description of the checkbox value
# Results:
#     The spin box widget ID is returned.
#----------------------------------------------------------------------------
proc GriddedCheckBox {parent rowNum legend subtext} {
    global convenience

    label $parent.$convenience -text $legend
    grid $parent.$convenience -row $rowNum -column 0 -sticky e
    incr convenience

    checkbutton $parent.$convenience -text $subtext
    grid $parent.$convenience -row $rowNum -column 1 -columnspan 2 -sticky nws
    set widgetOfInterest $parent.$convenience
    incr convenience

    return $widgetOfInterest
}

#----------------------------------------------------------------------------
# ConfigLayer --
#
#     Create a popup dialog to configure a specific image layer.
#
# Arguments:
#     buttonID - number of layer (1 at top) to be configured
# Results:
#     One image layer is reconfigured and the dialog is properly destroyed.
#----------------------------------------------------------------------------
proc ConfigLayer {buttonID} {
    global cfg
    scan $buttonID ".ftl.lf.b%d" number
    set w [toplevel .layerConfig]
    wm resizable $w 0 0
    wm title $w "Layer $number Properties"
    set result 0; # 0 = sentinel value

    label $w.ldir -text "Directory"
    entry $w.e
    button $w.dirButton -text "..." -command {
        set chosen [.layerConfig.e get]
        set chosen [tk_chooseDirectory -initialdir chosen -title "Choose directory for images"]
        if {$chosen ne ""} {
            .layerConfig.e delete 0 end
            .layerConfig.e insert end $chosen
        }
        raise .layerConfig
    }
    grid $w.ldir -row 0 -column 0 -sticky e
    grid $w.e -row 0 -column 1 -sticky news
    grid $w.dirButton -row 0 -column 2
    $w.e insert end [dict get $cfg layer $number directory]

    set hp [GriddedSpinBox $w 1 "Horizontal Padding" 0 128]
    $hp set [dict get $cfg layer $number hPad]
    set vp [GriddedSpinBox $w 2 "Vertical Padding" 0 128]
    $vp set [dict get $cfg layer $number vPad]

    ttk::separator $w.sep
    grid $w.sep -columnspan 3 -row 3 -sticky ew -pady 2

    frame $w.buttonRow
    grid $w.buttonRow -column 0 -row 4 -columnspan 3 -sticky ew
    ttk::button $w.buttonRow.ok -text OK -command {set ::done true}
    ttk::button $w.buttonRow.cancel -text Cancel -command {set ::done false}
    pack $w.buttonRow.cancel $w.buttonRow.ok -padx 2 -pady 2 -side right

    raise $w .
    vwait ::done
    if {$::done} {
        dict set cfg layer $number directory [$w.e get]
        dict set cfg layer $number hPad [$hp get]
        dict set cfg layer $number vPad [$vp get]
    }
    destroy $w
    return
}

#----------------------------------------------------------------------------
# ConfigProperties --
#
#     Create a popup dialog to configure general image properties.
#
# Results:
#     General DIPSAB image properties are configured.
#----------------------------------------------------------------------------
proc ConfigProperties {} {
    global cfg cbFooter cbHeader cbArticle cbSensitive
    set w [toplevel .propsConfig]
    wm resizable $w 0 0
    wm title $w "DIPSAB Properties"
    set result 0; # 0 = sentinel value

    label $w.ldir -text "Background Color"
    entry $w.e
    button $w.changeButton -text "..." -command {
        set chosen [.propsConfig.e get]
        if {$chosen == ""} { set chosen "#000" }
        set chosen [tk_chooseColor -initialcolor $chosen -title "Choose background color"]
        if {$chosen ne ""} {
            .propsConfig.e delete 0 end
            .propsConfig.e insert end $chosen
        }
        raise .propsConfig
    }
    grid $w.ldir -row 0 -column 0 -sticky e
    grid $w.e -row 0 -column 1 -sticky news
    grid $w.changeButton -row 0 -column 2
    $w.e insert end [dict get $cfg props bgColor]

    set bs [GriddedSpinBox $w 1 "Border Size" 0 400]
    $bs set [dict get $cfg props border]
    set hs [GriddedSpinBox $w 2 "Horizontal Size" 0 8000]
    $hs set [dict get $cfg props width]
    set vs [GriddedSpinBox $w 3 "Vertical Size" 0 6000]
    $vs set [dict get $cfg props height]

    set headerCB [GriddedCheckBox $w 4 "Header" "First Layer"]
    $headerCB configure -variable cbHeader
    set cbHeader [dict get $cfg props header]
    set footerCB [GriddedCheckBox $w 5 "Footer" "Last Layer"]
    $footerCB configure -variable cbFooter
    set cbFooter [dict get $cfg props footer]

    labelframe $w.lfs -text "Image Order Sorting Options"
    grid $w.lfs -row 6 -column 0 -columnspan 3 -sticky news -padx 2 -pady 2

    set sensitiveCB [GriddedCheckBox $w 7 " " "Case Sensitive"]
    $sensitiveCB configure -variable cbSensitive
    set cbSensitive [dict get $cfg props caseSensitive]
    set articleCB [GriddedCheckBox $w 8 " " "Disregard Articles ( A / An / The )"]
    $articleCB configure -variable cbArticle
    set cbArticle [dict get $cfg props disArticles]

    ttk::separator $w.sep
    grid $w.sep -row 9 -columnspan 3 -sticky ew -pady 2

    frame $w.buttonRow
    grid $w.buttonRow -column 0 -row 10 -columnspan 3 -sticky ew
    ttk::button $w.buttonRow.ok -text OK -command {set ::done true}
    ttk::button $w.buttonRow.cancel -text Cancel -command {set ::done false}
    pack $w.buttonRow.cancel $w.buttonRow.ok -padx 2 -pady 2 -side right

    raise $w .

    vwait ::done
    if {$::done} {
        dict set cfg props disArticles $cbArticle
        dict set cfg props caseSensitive $cbSensitive
        dict set cfg props header $cbHeader
        dict set cfg props footer $cbFooter
        dict set cfg props bgColor [$w.e get]
        dict set cfg props border [$bs get]
        dict set cfg props width [$hs get]
        dict set cfg props height [$vs get]
    }
    destroy $w
    return
}

#----------------------------------------------------------------------------
# CustomCompare --
#
#     lsort comparison proc with option to disregard leading articles.
#
# Arguments:
#     a - lhs argument of comparison.
#     b - rhs argument of comparison.
# Results:
#     Two strings are compared with a result of -1, 0 or 1.
#----------------------------------------------------------------------------
proc CustomCompare {a b} {
    global cfg
    set aBase [file rootname [file tail $a]]
    set bBase [file rootname [file tail $b]]
    if {[dict get $cfg props disArticles] == 1} {
        regsub -- {(?i)^(a|an|the)\s} $aBase "" aBase
        regsub -- {(?i)^(a|an|the)\s} $bBase "" bBase
    }

    if {[dict get $cfg props caseSensitive] == 1} {
        return [string compare $aBase $bBase]
    } else {
        return [string compare -nocase $aBase $bBase]
    }
}

#----------------------------------------------------------------------------
# CreateNewImage --
#
#     Brute force creation of the image.
#
# Results:
#     Image is created according to current configuration.
#----------------------------------------------------------------------------
proc CreateNewImage {} {
    global cfg

    set startY 0
    set endX [expr {[dict get $cfg props width] - 1}]
    set endY [expr {[dict get $cfg props height] - 1}]
    set border [dict get $cfg props border]
    set shim [dict get $cfg layer]; #temp dict shims between cfg and result
    set layers [dict size $shim]

    SetStatus "Creating background"
    set img [image create photo -height [expr {$endY + 1}] -width [expr {$endX + 1}]]
    $img put [dict get $cfg props bgColor] -to 0 0 $endX $endY
    .fi.ci configure -image $img
    update

    for {set n 1} {$n <= $layers} {incr n} {
        dict set shim $n rowImages {}
        dict set shim $n rowWidths {}
        dict set shim $n rowHeights {}
        set path [dict get $shim $n directory]
        if {[file isdirectory $path]} {
            set hpad [dict get $shim $n hPad]

            set imgFileNames {}
            foreach f [glob -nocomplain -directory $path *.{gif,jpg,png}] {
                lappend imgFileNames $f
            }
            set imgFileNames [lsort -decreasing -command CustomCompare $imgFileNames]
            set primed false
            foreach f $imgFileNames {
                SetStatus [format "Loading image: %s" $f]
                if {[::jpeg::isJPEG $f]} {
                    lassign [::jpeg::dimensions $f] w h
                    exec djpeg $f | pnmscale -xsize $w -ysize $h > tmp_buffer.ppm
                    set bufferImage [image create photo -file tmp_buffer.ppm]
                } else {; # TK built-in formats PNG, GIF, PPM
                    set bufferImage [image create photo -file $f]
                    set w [image width $bufferImage]
                    set h [image height $bufferImage]
                }

                if {$primed} {
                    if {[expr {$sumWidths + ($border * 2) + $w + $hpad}] <= $endX} {
                        lappend oneRowImages $bufferImage
                        set maxHeight [::tcl::mathfunc::max $maxHeight $h]
                        incr sumWidths [expr {$hpad + $w}]
                    } else {
                        dict with shim $n {lappend rowImages $oneRowImages}
                        dict with shim $n {lappend rowWidths $sumWidths}
                        dict with shim $n {lappend rowHeights $maxHeight}
                        set oneRowImages [list $bufferImage]
                        set maxHeight $h
                        set sumWidths $w
                    }
                } else {
                    set oneRowImages [list $bufferImage]
                    set maxHeight $h
                    set sumWidths $w
                    set primed true
                }
            }
            dict set cfg layer $n count [llength $imgFileNames]
            if {$oneRowImages ne {}} {
                dict with shim $n {lappend rowImages $oneRowImages}
                dict with shim $n {lappend rowWidths $sumWidths}
                dict with shim $n {lappend rowHeights $maxHeight}
            }
        }
    }
    catch {file delete tmp_buffer.ppm}

    if {[expr {$endY + 1}] < [expr {[SumHeights $shim 1 $layers] + 2 * $border}]} {
        set m [format "Height of canvas (%d pixels) insufficient for content and borders (%d pixels)" \
            [expr {$endY + 1}] [expr {[SumHeights $shim 1 $layers] + 2 * $border}]]
        tk_messageBox -message $m -icon error -type ok
        return $img
    }

    set parameters {}
    set startLayer 1
    if {[dict get $cfg props header]} {
        lappend parameters 1 $border
        set startY [expr {$border + [SumHeights $shim 1 1]}]
        set startLayer 2
    }

    set endLayer $layers
    if {[dict get $cfg props footer]} {
        set endY [expr {$endY - $border - [SumHeights $shim $layers $layers]}]
        lappend parameters $layers $endY
        incr endLayer -1
    }

    set bodyHeight [SumHeights $shim $startLayer $endLayer]
    set offsetY [expr {$startY + (($endY - $startY - $bodyHeight) / 2)}]
    for {set n $startLayer} {$n <= $endLayer} {incr n} {
        lappend parameters $n $offsetY
        incr offsetY [expr {$border + [SumHeights $shim $n $n]}]
    }

    foreach {n y} $parameters {
        SetStatus [format "Assembling layer %d images" $n]
        set img [PlaceRowImages $img [dict get $shim $n] $endX $y]
    }

    SetStatus default
    return $img
}

#----------------------------------------------------------------------------
# SumHeights --
#
#     Sum in pixels the heights of layers.
#
# Arguments:
#     rowConfig - dict of row configurations.
#     rowFrom - layer number of sum start.
#     rowTo - layer number of sum end (Inclusive).
# Results:
#     Number of pixels of vertical size for range of heights.
#----------------------------------------------------------------------------
proc SumHeights {rowConfig rowFrom rowTo} {
    global cfg
    set result 0
    for {set n $rowFrom} {$n <= $rowTo} {incr n} {
        if {$n > $rowFrom} {
            incr result [dict get $cfg props border]
        }
        set vpad 0
        foreach h [dict get $rowConfig $n rowHeights] {
            incr result [expr {$vpad + $h}]
            set vpad [dict get $cfg layer $n vPad]
        }
    }
    return $result
}

#----------------------------------------------------------------------------
# PlaceRowImages --
#
#     Copy directory images to final locations.
#
# Arguments:
#     img - working copy of final image
#     rowConfig - dict of row configurations.
#     endX - pixels of horizontal span in final image.
#     offsetY - pixels offset in vertical span before rendering body image.
# Results:
#     Working copy of final image shown with updates for each layer.
#----------------------------------------------------------------------------
proc PlaceRowImages {img rowConfig endX offsetY} {
    set vpad [dict get $rowConfig vPad]
    foreach oneRowImages [lreverse [dict get $rowConfig rowImages]] \
            w [lreverse [dict get $rowConfig rowWidths]] \
            h [lreverse [dict get $rowConfig rowHeights]] {
        set offsetX [expr {($endX - $w) / 2}]
        set hpad [dict get $rowConfig hPad]
        foreach i [lreverse $oneRowImages] {
            set ih [image height $i]
            $img copy $i -to $offsetX [expr {$offsetY + ($h - $ih) / 2}]
            incr offsetX [expr {$hpad + [image width $i]}]
        }
        incr offsetY [expr {$vpad + $h}]
    }
    ShowImage $img
    return $img
}

#----------------------------------------------------------------------------
# ResizePercent --
#
#     Resize an image by an integer percentage.
#
# Arguments:
#     original - working copy of final image
#     percent - amount of scaling to be performed in each dimension (x & y).
# Results:
#     Resized copy of final image.
#----------------------------------------------------------------------------
proc ResizePercent {original percent} {
    set den [gcd $percent 100]
    set zoomIn  [expr {$percent / $den}]
    set zoomOut [expr {     100 / $den}]

    set img1 [image create photo]
    $img1 copy $original -zoom 1 $zoomIn
    set img2 [image create photo]
    $img2 copy $img1 -subsample 1 $zoomOut

    set img1 [image create photo]
    $img1 copy $img2 -zoom $zoomIn 1
    set img2 [image create photo]
    $img2 copy $img1 -subsample $zoomOut 1

    return $img2
}

#----------------------------------------------------------------------------
# ShowImage --
#
#     Display any image resized by an integer percentage.
#
# Arguments:
#     showing - arbitrary image.
# Results:
#     The resized image is displayed in application widget.
#----------------------------------------------------------------------------
proc ShowImage {showing} {
    global cfg
    set percentH [Per100 [winfo height .fi] [dict get $cfg props height]]
    set percentW [Per100 [winfo width  .fi] [dict get $cfg props width]]
    set displayPercent [expr min($percentH, $percentW)]
    set resized [ResizePercent $showing $displayPercent]
    .fi.ci configure -image $resized
    return
}

#----------------------------------------------------------------------------
# RenderFinal --
#
#     Top level proc to render the final image without events.
#
# Results:
#     The image is properly rendered.
#----------------------------------------------------------------------------
proc RenderFinal {} {
    global cfg
    if {[dict get $cfg previewing] == false} {
        dict set cfg previewing true
        set md5cat [md5::Hex [dict get $cfg props]][md5::Hex [dict get $cfg layer]]
        set rendering [expr {$md5cat ne [dict get $cfg md5cat]}]
        if {$rendering} {
            SetStatus "Creating Image"
            dict set cfg img [CreateNewImage]
            dict set cfg md5cat [md5::Hex [dict get $cfg props]][md5::Hex [dict get $cfg layer]]
        }
        set renderW [expr {[dict get $cfg xSize] != [winfo width .fi]}]
        set renderH [expr {[dict get $cfg ySize] != [winfo height .fi]}]
        if {$rendering || $renderW || $renderH} {
            SetStatus "Resizing Image"
            dict set cfg xSize [winfo width .fi]
            dict set cfg ySize [winfo height .fi]
            ShowImage [dict get $cfg img]
            SetStatus
        }
        dict set cfg previewing false
    }
    return
}

#----------------------------------------------------------------------------
# gcd --
#
#     Recursively compute the greatest common denominator.
#
# Arguments:
#     u - one integer.
#     v - other integer.
# Result:
#     The greatest common denominator.
#----------------------------------------------------------------------------
proc gcd {u v} {
    return [expr {$u? [gcd [expr $v % $u] $u]: $v}]
}

#----------------------------------------------------------------------------
# Per100 --
#
#     Integer percentage of ratio.
#
# Arguments:
#     num - numerator of the ratio.
#     den - denominator of the ratio.
# Result:
#     Integer percentage (0-100).
#----------------------------------------------------------------------------
proc Per100 {num den} {
    return [expr {int((100 * $num) / $den)}]
}

#----------------------------------------------------------------------------
# SetStatus --
#
#     Repopulate the status bar message.
#
# Arguments:
#     statusMsg (optional) - text string or default.
# Result:
#     Status bar displays proper text.
#----------------------------------------------------------------------------
proc SetStatus {{statusMsg "default"}} {
    global cfg
    if {$statusMsg == "default"} {
        set layers [dict size [dict get $cfg layer]]
        if {$layers > 0} {
            set statusMsg [format "displayed: %d" [dict get $cfg layer 1 count]]
            for {set n 2} {$n <= $layers} {incr n} {
                append statusMsg [format " / %d" [dict get $cfg layer $n count]]
            }
            append statusMsg " (images per layer)"

            set ratioW [Per100 [dict get $cfg xSize] [dict get $cfg props width]]
            set ratioH [Per100 [dict get $cfg ySize] [dict get $cfg props height]]
            append statusMsg [format "        Linear Scale: %d%%" \
                    [::tcl::mathfunc::min $ratioW $ratioH]]
        } else {
            set statusMsg "No layers configured."
        }
    }
    .statusbar configure -text $statusMsg
    update
    return
}

#----------------------------------------------------------------------------
# RangedIntDlg --
#
#     Popup dialog to display an integer from a range.
#
# Arguments:
#     legend - Text to display next to spinbox.
#     start - Low number of the available integer range.
#     limit - High number of the available integer range.
# Result:
#     Positive integer for a valid number, or zero if cancelled.
#----------------------------------------------------------------------------
proc RangedIntDlg {legend start limit} {
    set w [toplevel .rangedIntSpin]
    wm resizable $w 0 0
    wm title $w "Select Number"
    set result 0; # 0 = sentinel value

    label $w.l -text $legend
    if {$start != $limit} {
        spinbox $w.s -from $start -to $limit
    } else {
        set vlist [format "{%d}" $start]
        spinbox $w.s -values $vlist
    }

    button $w.ok     -text "  OK  " -command {set ::done true}
    button $w.cancel -text "Cancel" -command {set ::done false}

    grid $w.l -columnspan 2 -sticky news
    grid $w.s -columnspan 2 -sticky news
    grid $w.ok $w.cancel -sticky news

    raise $w .
    focus $w.s

    vwait ::done
    if {$::done} {
        set result [$w.s get]
    }
    destroy $w
    return $result
}

#----------------------------------------------------------------------------
# EverySecond --
#
#     Run some body of code a given number of times every second.
#
# Arguments:
#     hz - number of times per second.
#     body - code to be evaluated at specified frequency.
# Results:
#     Depends upon the body of code passed in.
#----------------------------------------------------------------------------
proc EverySecond {hz body} {
    set elapsed [string range [time $body] 0 end-27]
    after [expr {1000/$hz - $elapsed/1000}] [namespace code [info level 0]]
    return
}

UpdateRecentFiles
EverySecond 1 RenderFinal
SetStatus default
