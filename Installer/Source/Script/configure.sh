#!/bin/bash

#
#  file: configure.sh
#  project: RansomWhere
#  description: install/uninstall
#
#  created by Patrick Wardle
#  copyright (c) 2026 Objective-See. All rights reserved.
#

#where binary goes
INSTALL_DIRECTORY="/Library/Objective-See/RansomWhere"

#preferences
PREFERENCES="$INSTALL_DIRECTORY/preferences.plist"

#OS version check
# only support macOS 15+
major=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$major" -lt 15 ]]; then
    printf "\nERROR: macOS 15+ required\n\n"
    exit 1
fi

#auth check
# gotta be root
if [ "${EUID}" -ne 0 ]; then
    echo "\nERROR: must be run as root\n"
    exit 1
fi

#install logic
if [ "${1}" == "-install" ]; then

    echo "installing"

    #change into dir
    cd "$(dirname "${0}")"

    #remove all xattrs
    xattr -rc ./*

    #create main directory
    mkdir -p "$INSTALL_DIRECTORY"

    #install launch daemon
    chown -R root:wheel "RansomWhere.app"
    chown -R root:wheel "com.objective-see.ransomwhere.plist"

    cp -R -f "RansomWhere.app" "$INSTALL_DIRECTORY"
    cp "com.objective-see.ransomwhere.plist" /Library/LaunchDaemons/
    echo "launch daemon installed"

    #install app
    cp -R -f "RansomWhere Helper.app" "/Applications"
    echo "app installed"

    #no preferences?
    # create defaults
    if [ ! -f "$PREFERENCES" ]; then

        /usr/libexec/PlistBuddy -c 'add disabled bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add noIconMode bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add noUpdateMode bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add notarizationMode bool false' "$PREFERENCES"
        /usr/libexec/PlistBuddy -c 'add gotFullDiskAccess bool false' "$PREFERENCES"

    fi

    echo "install complete"
    exit 0

#uninstall logic
elif [ "${1}" == "-uninstall" ]; then

    echo "uninstalling"

    #kill first
    killall RansomWhere 2> /dev/null
    killall com.objective-see.RansomWhere.helper 2> /dev/null
    killall "RansomWhere Helper" 2> /dev/null

    #unload launch daemon & remove its plist
    launchctl bootout system /Library/LaunchDaemons/com.objective-see.ransomwhere.plist
    rm "/Library/LaunchDaemons/com.objective-see.ransomwhere.plist"
    
    rm -rf "$INSTALL_DIRECTORY/RansomWhere"
    rm -rf "$INSTALL_DIRECTORY/RansomWhere.app"
    echo "unloaded launch daemon"

    #remove main app/helper app
    rm -rf "/Applications/RansomWhere Helper.app"

    #full uninstall?
    # delete RansomWhere's folder w/ everything
    if [[ "${2}" == "1" ]]; then
        rm -rf "$INSTALL_DIRECTORY"

        #no other Objective-See tools?
        # then delete that directory too
        baseDir=$(dirname "$INSTALL_DIRECTORY")

        if [ ! "$(ls -A "$baseDir")" ]; then
            rm -rf "$baseDir"
        fi
    fi

    echo "uninstall complete"
    exit 0
fi

#invalid args
echo ""
echo "ERROR: run w/ '-install' or '-uninstall'"
echo ""
exit 1
