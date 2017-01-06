#!/bin/bash
# Author: https://github.com/ericleong/slickr
# Author2: https://github.com/huaping/slickr

help__()
{
     echo "Usage: `basename ${0}` -s <PhoneID> -p <package> -c <iterations>  -H"
     echo "-s deviceid, device under test, if you don't specify, only one device need on PC'"
     echo "-p       package  Package to get"
     echo "-c       iterations  collect data for count time"
     echo "-d       distance, "
     echo "-H       horizontal scrolling, if this is "
     echo " slickr.sh -p <package> -c <iterations>  -H"
     adb devices
}

HSWIPE=0
ADB=adb
COUNT=4
DISTANCE=""
PKG=""
CUR_DIR=$(cd "$(dirname "$0")"; pwd)
while getopts :s:c:p:d:Hh opt
do
  case "${opt}" in
    s) ADB="adb -s ${OPTARG}";;
    c) COUNT=${OPTARG};;
    d) DISTANCE=${OPTARG};;
    p) PKG=${OPTARG};;
    H) HSWIPE=1;;
    h) help__;;
    \?) help__;;
  esac
done


# Specify the package name of the Android app you want to track
# as the first argument.

# Vertical pixels to swipe
if [ "$DISTANCE" = "" ] ; then

    # Try to get density with "wm"
    # Physical size: 1440x2560
    LCDSIZE=$($ADB shell wm size)
    DENSITY=$($ADB shell wm density)

    if [[  "$LCDSIZE" =~ "Physical size" ]]; then
        WIDTH=$(echo "$LCDSIZE" |  awk '{print $3}' | awk -F"x" '{print $1}')
        HEIGHT=$(echo "$LCDSIZE" |  awk '{print $3}' | awk -F"x" '{print $2}')
        WIDTH2=$(expr $WIDTH / 2)
        HEIGHT2=$(expr $HEIGHT / 2)
        W_E1=$(expr $WIDTH / 6)
        W_E2=$(expr $WIDTH - $W_E1)
        H_E1=$(expr $HEIGHT / 6)
        H_E2=$(expr $HEIGHT - $H_E1)
    fi

    if [[ $DENSITY == *"wm: not found"* ]] ; then
        # Grab density with "getprop"
        DENSITY=$($ADB shell getprop | grep density)
    fi

    # Grab actual density value
    DENSITY=$(echo $DENSITY | grep -o "[0-9]\+")

    VERTICAL=$(expr $DENSITY \* 3)
else
    VERTICAL=$DISTANCE
fi

# Android Marshmallow features
# http://developer.android.com/preview/testing/performance.html#timing-info
VERSION=$($ADB shell getprop ro.build.version.release)
MAJOR_VERSION=$(echo $VERSION | cut -c 1)
MINOR_VERSION=$(echo $VERSION | cut -c 3)
if [ "$PKG" != "" ] ; then
    # Test if integer, then test if >= 6.0
    if [[ "$MAJOR_VERSION" =~ ^-?[0-9]+$ ]] && [ "$MAJOR_VERSION" -ge "6" ] ; then
        FRAMESTATS="framestats"
    elif [ "$MAJOR_VERSION" == "N" ] ; then # N preview
        FRAMESTATS="framestats"
    fi
fi

# Scroll command differs by version

SWIPE="touchscreen swipe"
DURATION="250"

if [[ "$MAJOR_VERSION" =~ ^-?[0-9]+$ ]] ; then
    if [ "$MAJOR_VERSION" -ge "5" ] ; then
        :
    elif [ "$MAJOR_VERSION" -ge "4" ] && [ "$MINOR_VERSION" -gt "1" ] ; then
        :
    else
        # Old device
        SWIPE="swipe"
        DURATION=""
    fi
fi

# Empty old data
$ADB shell dumpsys gfxinfo $PKG reset > /dev/null

# Collect data for $COUNT times
if [ $COUNT -gt "1" ] ; then

    # Swipe three times for 250 ms each.
    # $ADB shell is a little slow, so when this is finished,
    # about 128 frames (2 seconds at 60 fps) should have passed.
    # Afterwards, dump data and filter for profile data
    if [ $HSWIPE -eq 1 ]; then
        #                                                                                                                                                                       startX          startY      endX  endY                                                          startX  startY     endX         endY
        #$ADB shell "for i in `seq -s ' ' 1 $COUNT`; do for j in `seq -s ' ' 1 3`; do input $SWIPE $VERTICAL $DENSITY 100 $DENSITY $DURATION; input $SWIPE 100 $DENSITY $VERTICAL $DENSITY $DURATION; done; dumpsys gfxinfo $PKG $FRAMESTATS; done;" | python "$CUR_DIR/profile.py"
        $ADB shell "for i in `seq -s ' ' 1 $COUNT`; do for j in `seq -s ' ' 1 3`; do input $SWIPE $W_E2 $HEIGHT2 $W_E1 $HEIGHT2 $DURATION; input $SWIPE $W_E1 $HEIGHT2 $W_E2 $HEIGHT2 $DURATION; done; dumpsys gfxinfo $PKG $FRAMESTATS; done;" | python "$CUR_DIR/profile.py"
    else
        #$ADB shell "for i in `seq -s ' ' 1 $COUNT`; do for j in `seq -s ' ' 1 3`; do input $SWIPE 200 $VERTICAL 200 0 $DURATION; input $SWIPE 100 100 100 $VERTICAL $DURATION;done; dumpsys gfxinfo $PKG $FRAMESTATS; done;" | python "$CUR_DIR/profile.py"
        $ADB shell "for i in `seq -s ' ' 1 $COUNT`; do for j in `seq -s ' ' 1 3`; do input $SWIPE $WIDTH2 $H_E2 $WIDTH2 $H_E1 $DURATION; input $SWIPE $WIDTH2 $H_E1 $WIDTH2 $H_E2 $DURATION;done; dumpsys gfxinfo $PKG $FRAMESTATS; done;" | python "$CUR_DIR/profile.py"
    fi
else
    if [ $HSWIPE -eq 1 ]; then
        $ADB shell "for j in `seq -s ' ' 1 3`; do input $SWIPE $W_E2 $HEIGHT2 $W_E1 $HEIGHT2 $DURATION; input $SWIPE $W_E1 $HEIGHT2 $W_E2 $HEIGHT2 $DURATION; done; dumpsys gfxinfo $PKG $FRAMESTATS;" | python "$CUR_DIR/profile.py"
    else
        $ADB shell "for j in `seq -s ' ' 1 3`; do input $SWIPE $WIDTH2 $H_E2 $WIDTH2 $H_E1 $DURATION; input $SWIPE $WIDTH2 $H_E1 $WIDTH2 $H_E2 $DURATION;done; dumpsys gfxinfo $PKG $FRAMESTATS;" | python "$CUR_DIR/profile.py"
    fi
fi
