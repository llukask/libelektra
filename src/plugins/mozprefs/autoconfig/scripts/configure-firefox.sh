#!/bin/bash

WorkingDir=$(dirname $0)
TriggerPort=65432
MountPoint="user/prefs"
PrefsSetupMountPoint="system/firefox/prefs"
ConfigFile="myPrefs.js"
Decoy="/tmp/imnotreal.js"
AutoConfigScript="elektra.cfg"
AutoConfigLauncher="autoconfig.js"
FFInterceptKey="system/firefox/intercept/running"
FFInterceptConfig="system/firefox/intercept/userprefs"
FFInterceptLibDir="system/firefox/intercept/libdir"
PrefsFile=
FFLibDir=

testFFRunning()
{
    pgrep firefox &>/dev/null
    echo $?
}

initialize()
{
    kdb check mozprefs &>/dev/null

    hasPrefsPlugin=$?

    if [ "$hasPrefsPlugin" -ne 0 ]; 
    then
	echo "Error, mozprefs plugin not found"
	exit 1
    fi

    kdb mount-info &>/dev/null

    libDir=$(kdb get system/info/constants/package/libdir)
    if [ -z "$libDir" ];
    then
	echo "Error, elektra libdir not found"
	exit 1
    fi

    interceptFile="${libDir}/libelektraintercept.so"

    if [ ! -e "$interceptFile" ];
    then
	echo "Error, libelektraintercept.so not found"
	exit 1
    fi

    FFLibDir=$(find /usr/lib /usr/lib32 /usr/lib64 /usr/local/lib -name "firefox*" -type f | xargs dirname 2>/dev/null|sort|uniq)
    if [ -z "$FFLibDir" ];
    then
	echo "Error, couldn't find any Firefox library directory"
	exit 1
    fi
    resNo=$(echo "$FFLibDir" | wc -l)
    if [ "$resNo" -gt 1 ];
    then
	i=1;
	for line in ${FFLibDir};
	do
	    echo "$i) $line"
	    i=$((++i))
	done

	echo -n "Select your Firefox library directory: "
	read -r sel

	FFLibDir=$(sed "${sel}q;d" <<< "$FFLibDir")
    fi

    echo "Firefox library directory: $FFLibDir"
    echo
    
    userConfigDir="${HOME}/.mozilla/firefox/"
    Profile=$(find "$userConfigDir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null|sort|uniq)
    if [ -z "$Profile" ];
    then
	echo "Couldn't find Firefox profile directory in $userConfigDir"
	echo -n "Please enter your Firefox profile directory: "
	read -r Profile
    fi
    if [ -z "$Profile" ];
    then
	echo "Invalid profile directory"
	exit 1
    fi

    resNo=$(echo "$Profile" | wc -l)
    if [ "$resNo" -gt 1 ];
    then
	i=1;
	for line in ${Profile};
	do
	    echo "$i) `basename $line`"
	    i=$((++i))
	done
	echo -n "Select your Firefox profile directory: "
	read -r sel
	Profile=$(sed "${sel}q;d" <<< "$Profile")
    fi

    echo "Firefox profile directory: `basename $Profile`"
    echo

    PrefsFile=$(readlink -f "${Profile}/prefs.js")
    echo "prefsFile: $PrefsFile"
    if [ ! -e "$PrefsFile" ];
    then
	echo "Error, prefs file $PrefsFile doesn't exist"
	exit 1
    fi

    FFrunning=$( testFFRunning )
    if [ "$FFrunning" -eq "0" ];
    then
	echo "We detected that Firefox is running on your computer."
	read -p "Please close Firefox that uses $PrefsFile and press any key to continue."
    fi
    FFrunning=$( testFFRunning )
    if [ "$FFrunning" -eq "0" ];
    then
	echo "Error, Firefox is sill running"
	exit 1
    fi
}

testAutoPrefs()
{
    unset prefTest
    unset errCount
    errCount=0
    prefTest=$(kdb sget "${PrefsSetupMountPoint}/user/elektra/config/file" NA)
    if [ "$prefTest" != "$Decoy" ];
    then
	echo "Error, failed to set elektra.config.file in $PrefsFile"
	errCount=$((++errCount))
    fi
    unset prefTest
    prefTest=$(kdb sget "${PrefsSetupMountPoint}/user/elektra/config/reload_trigger_port" NA)
    if [ "$prefTest" != "$TriggerPort" ];
    then
	echo "Error, failed to set elektra.config.reload_trigger_port in $PrefsFile"
	errCount=$((++errCount))
    fi
    echo $errCount
}

setAutoPrefs()
{
    kdb mount "$PrefsFile" "$PrefsSetupMountPoint" mozprefs &>/dev/null
    if [ $? -ne 0 ];
    then
	echo "Error, Mountpoint $PrefsSetupMountPoint already in use"
	exit 1
    fi
    kdb setmeta "${PrefsSetupMountPoint}/user/elektra/config/file" type string &>/dev/null
    kdb set "${PrefsSetupMountPoint}/user/elektra/config/file" "$Decoy" &>/dev/null
    kdb setmeta "${PrefsSetupMountPoint}/user/elektra/config/reload_trigger_port" type string &>/dev/null
    kdb set "${PrefsSetupMountPoint}/user/elektra/config/reload_trigger_port" "$TriggerPort" &>/dev/null
    errCount=$( testAutoPrefs )
    kdb umount "$PrefsSetupMountPoint" &>/dev/null
    if [ "$errCount" -gt "0" ];
    then
	exit 1
    fi
    kdb set "$FFInterceptConfig" "$PrefsFile" &>/dev/null
}

testPreload()
{
    escapedDecoy=$(echo "$Decoy"|sed 's/\//\\\//g')
    unset valTest
    unset errCount
    errCount=0
    valTest=$(kdb sget "/preload/open/${escapedDecoy}" NA)
    if [ "$valTest" == "NA" ];
    then
	errCount=$((++errCount))
    fi
    valTest=$(kdb sget "/preload/open/${escapedDecoy}/generate" NA)
    if [ "$valTest" != "$MountPoint" ];
    then
	errCount=$((++errCount))
    fi
    valTest=$(kdb sget "/preload/open/${escapedDecoy}/generate/plugin" NA)
    if [ "$valTest" != "mozprefs" ];
    then
	errCount=$((++errCount))
    fi
    if [ $errCount -ne 0 ];
    then
	echo "Error, failed to setup /preload/open configuration"
	exit 1
    fi
}

setPreload()
{
    kdb set /preload/open 
    escapedDecoy=$(echo "$Decoy"|sed 's/\//\\\//g')
    kdb set "/preload/open/${escapedDecoy}" ""
    kdb set "/preload/open/${escapedDecoy}/generate" "$MountPoint"
    kdb set "/preload/open/${escapedDecoy}/generate/plugin" mozprefs
}

setTestPrefs()
{
    kdb mount "$ConfigFile" "$MountPoint" mozprefs shell execute/set="echo -n \"reload\"|nc 127.0.0.1 $TriggerPort"
    kdb setmeta "${MountPoint}/lock/a/lock/1" type string
    kdb set "${MountPoint}/lock/a/lock/1" "lock1"
    kdb setmeta "${MountPoint}/lock/a/lock/2" type string
    kdb set "${MountPoint}/lock/a/lock/2" "lock2"
    kdb setmeta "${MountPoint}/pref/a/default/1" type integer
    kdb set "${MountPoint}/pref/a/default/1" 1
    kdb setmeta "${MountPoint}/pref/a/default/2" type integer
    kdb set "${MountPoint}/pref/a/default/2" 2
    kdb setmeta "${MountPoint}/user/a/user/t" type boolean 
    kdb set "${MountPoint}/user/a/user/t" true
    kdb setmeta "${MountPoint}/user/a/user/f" type boolean
    kdb set "${MountPoint}/user/a/user/f" false

}

setupAutoConfig()
{
    set -x
    su -c "${WorkingDir}/writeConfigFiles.sh \"$FFLibDir\" \"$AutoConfigScript\" \"$AutoConfigLauncher\""
    set +x
    kdb set "$FFInterceptLibDir" "$FFLibDir"
}

main()
{
    isSetup=$(kdb sget $FFInterceptKey "false")
    if [ "$isSetup" == "true" ];
    then
	echo "Overwrite existing configuration ? (y/n)"
	read -s -n 1 sel
	if [ "$sel" != "y" ];
	then
	    return
	fi
    fi 
    initialize

    setAutoPrefs

    setPreload &>/dev/null
    testPreload

    setupAutoConfig

    kdb set ${FFInterceptKey} "true"
}

usage()
{
    echo -e "Usage: ./configure-firefox.sh -arst\n\ta) Add new peference\n\tc) Clear preferences\n\tr) Remove everything\n\ts) Setup only\n\tt) Setup with test values"
}

removePrefs()
{
    isSetup=$(kdb sget $FFInterceptKey "false")
    if [ "$isSetup" == "true" ];
    then
	kdb rm "$FFInterceptKey" &>/dev/null
	escapedDecoy=$(echo "$Decoy"|sed 's/\//\\\//g')
	kdb rm -r "/preload/open/${espacedDecoy}" &>/dev/null
        kdb rm -r "$MountPoint" &>/dev/null
	kdb umount "$MountPoint" &>/dev/null
	tmpPrefsFile=$(kdb get "$FFInterceptConfig")
	kdb mount "$tmpPrefsFile" "$PrefsSetupMountPoint" mozprefs &>/dev/null
	kdb rm -r "${PrefsSetupMountPoint}/user/elektra" &>/dev/null
	kdb umount "$PrefsSetupMountPoint" &>/dev/null
	tmpLibDir=$(kdb get "$FFInterceptLibDir")
	set -x
	su -c "rm ${tmpLibDir}/${AutoConfigScript}; rm ${tmpLibDir}/defaults/pref/${AutoConfigLauncher}"
	set +x
	kdb rm "$FFInterceptKey" &>/dev/null
	kdb rm "$FFInterceptConfig" &>/dev/null
	kdb rm "$FFInterceptLibDir" &>/dev/null
    fi
}

clearPrefs()
{
    isSetup=$(kdb sget $FFInterceptKey "false")
    if [ "$isSetup" == "true" ];
    then
        kdb rm -r "$MountPoint" &>/dev/null
    fi
}

if [ "$#" -eq 0 ];
then
    usage
    exit 0
fi

while getopts "acstr" opt;
do
    case "$opt" in
	t)
	    echo "Setting up with test values"
	    main
	    setTestPrefs &>/dev/null
	    exit 0
	    ;;
	a)
	    echo "Add new preferences"
	    main
	    ( . "${WorkingDir}/setupConfig.sh" )
	    exit 0
	    ;;
	c)
	    echo "Clear preferences"
	    clearPrefs
	    exit 0
	    ;;
	s)
	    echo "Setup only"
	    main
	    exit 0
	    ;;
	r)
	    echo "Remove everything"
	    removePrefs
	    exit 0
	    ;;
	*)
	    usage
	    exit 0
	    ;;
    esac
done
