#!/bin/bash

#set -x

rehabman=0
quiet=1
spoof_class_code=0
override_md5=0
# assume patching system volume kext
unpatched=/System/Library/Extensions/IONVMeFamily.kext

while [[ $# -gt 0 ]]; do
    if [[ "$1" == --spoof ]]; then
        spoof_class_code=1
        shift
    elif [[ "$1" == --unpatched ]]; then
        unpatched="$2"
        shift 2
    elif [[ "$1" == --override ]]; then
        override_md5=1
        shift
    elif [[ "$1" == --rehabman ]]; then
        rehabman=1
        shift
    else
        break
    fi
done

plistbuddy=/usr/libexec/PlistBuddy
patch_name=$1

if [[ "$patch_name" == "" ]]; then
    vanilla_md5=`md5 -q $unpatched/Contents/MacOS/IONVMeFamily`
    for check in NVMe_patches_*.plist; do
        expected_md5=`$plistbuddy -c "Print :VanillaMD5" $check 2>&1`
        if [[ "$expected_md5" == "$vanilla_md5" ]]; then
            patch_name=${check#NVMe_patches_}
            patch_name=${patch_name%.plist}
            echo "Determined patch automatically from vanilla IONVMeFamily: $patch_name"
            break
        fi
    done
fi

if [[ "$patch_name" == "" ]]; then
    echo "ERROR: no patch name specified, and unable to determine a suitable patch automatically"
    exit
fi

if [[ ! -e NVMe_patches_$patch_name.plist ]]; then
    echo "ERROR: $NVMe_patches_$patch_name.plist does not exist!"
    exit
fi

binpatch=./binpatch
if [[ ! -e $binpatch ]]; then
    cc -o binpatch binpatch.c
fi
if [[ ! -e $binpatch ]]; then
    echo "ERROR: $binpatch does not exist... cannot binary patch!"
    exit
fi

# list of known PCIe SSDs
# pci144d,a802 = Samsung 950 Pro NVMe
# pci144d,a804 = Samsung 960 EVO NVMe
# pci1987,5007 = Zotac Sonix PCIe 480gb
devids=("pci144d,a802" "pci144d,a804" "pci1987,5007")
# devids only used if use_class_match=0
use_class_match=1

# as to whether the patched kext uses renamed classes/bundle
rename_class=1


config=NVMe_patches_$patch_name.plist
if [[ $spoof_class_code -eq 0 ]]; then
    patched=HackrNVMeFamily-$patch_name.kext
else
    patched=HackrNVMeFamily-${patch_name}-spoof.kext
fi
disasm=HackrNVMeFamily-$patch_name.s
orgdisasm=NVMeFamily-$patch_name.s

if [[ $rehabman -eq 1 ]]; then
    unpatched=./unpatched/IONVMeFamily_$patch_name.kext
fi

echo "Creating patched $patched from $unpatched"

rm -Rf $patched
cp -RX $unpatched $patched
if [[ rename_class -eq 1 ]]; then
    bin=$patched/Contents/MacOS/HackrNVMeFamily
    mv $patched/Contents/MacOS/IONVMeFamily $bin
else
    bin=$patched/Contents/MacOS/IONVMeFamily
fi

expected_md5=`$plistbuddy -c "Print :VanillaMD5" $config 2>&1`
if [[ "$expected_md5" == *"Does Not Exist"* ]]; then
    echo "WARNING: patch file \"$config\" has no VanillaMD5 entry, not comparing md5 values"
else
    vanilla_md5=`md5 -q $bin`
    if [[ "$vanilla_md5" == "$expected_md5" ]]; then
        echo "Vanilla MD5 matches expected MD5 entry ($expected_md5)"
    else
        echo "WARNING: Vanilla MD5 ($vanilla_md5) does not match expected MD5 ($expected_md5)"
        if [[ $override_md5 -eq 0 ]]; then
            echo "ERROR: Vanilla MD5 does not match and --override not specified.  No kext generated!"
            exit
        fi
    fi
fi

if [[ $quiet -eq 1 ]]; then
    binpatch_flags=-q
fi

# patch binary using IONVMeFamily patches in config.plist/KernelAndKextPatches/KextsToPatch
for ((patch=0; 1; patch++)); do
    comment=`$plistbuddy -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Comment" $config 2>&1`
    if [[ "$comment" == *"Does Not Exist"* ]]; then
        break
    fi
    # skip any patches not for IONVMeFamily, disabled, or InfoPlistPatch
    name=`$plistbuddy -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Name" $config 2>&1`
    if [[ "$name" != "IONVMeFamily" ]]; then continue; fi
    disabled=`$plistbuddy -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Disabled" $config 2>&1`
    if [[ "$disabled" == "true" ]]; then continue; fi
    infoplist=`$plistbuddy -c "Print :KernelAndKextPatches:KextsToPatch:$patch:InfoPlistPatch" $config 2>&1`
    if [[ "$infoplist" == "true" ]]; then continue; fi
    # otherwise, it is enabled binpatch
    if [[ $quiet -eq 0 ]]; then
        printf "Comment: %s\n" "$comment"
    fi
    find=`$plistbuddy -x -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Find" $config 2>&1`
    repl=`$plistbuddy -x -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Replace" $config`
    find=$([[ "$find" =~ \<data\>(.*)\<\/data\> ]] && echo ${BASH_REMATCH[1]})
    repl=$([[ "$repl" =~ \<data\>(.*)\<\/data\> ]] && echo ${BASH_REMATCH[1]})
    find=`echo $find | base64 --decode | xxd -p | tr '\n' ' '`
    repl=`echo $repl | base64 --decode | xxd -p | tr '\n' ' '`
    $binpatch $binpatch_flags "$find" "$repl" $bin
done

# show md5 with just normal patches from Pike
if [[ $quiet -eq 0 || $rehabman -ge 2 ]]; then
    echo md5 $bin: `md5 -q $bin`
fi
if [[ $rehabman -ge 2 ]]; then
    echo md5 frompike/IONVMeFamily_10115_Step_2: `md5 -q frompike/IONVMeFamily_10115_Step_2`
    echo md5 frompike/IONVMeFamily_WORKS_Step_9_Y: `md5 -q frompike/IONVMeFamily_WORKS_Step_9_Y`
fi

if [[ rename_class -eq 1 ]]; then
    # rename classes
    if [[ $quiet -eq 0 ]]; then
        echo "Rename class from AppleNVMeController to HackrNVMeController"
    fi
    $binpatch $binpatch_flags 004170706c654e564d65436f6e74726f6c6c657200 004861636b724e564d65436f6e74726f6c6c657200 $bin
    if [[ 0 -eq 1 ]]; then
        # rename internal classes
        # these renames are disabled as instead we rename the classes in the native kext
        $binpatch $binpatch_flags 00494f4e564d65436f6e74726f6c6c657200 0049584e564d65436f6e74726f6c6c657200 $bin
        $binpatch $binpatch_flags 00494f4e564d65426c6f636b53746f7261676544657669636500 0049584e564d65426c6f636b53746f7261676544657669636500 $bin
        $binpatch $binpatch_flags 004170706c654e564d65576f726b4c6f6f7000 004861636b724e564d65576f726b4c6f6f7000 $bin
        $binpatch $binpatch_flags 004170706c65533158436f6e74726f6c6c657200 004861636b72533158436f6e74726f6c6c657200 $bin
        $binpatch $binpatch_flags 00494f4e564d65436f6e74726f6c6c6572506f6c6c65644164617074657200 0049584e564d65436f6e74726f6c6c6572506f6c6c65644164617074657200 $bin
        $binpatch $binpatch_flags 004170706c654e564d6542756666657200 004861636b724e564d6542756666657200 $bin
        $binpatch $binpatch_flags 004170706c654e564d655265717565737400 004861636b724e564d655265717565737400 $bin
        $binpatch $binpatch_flags 004170706c655333454c6162436f6e74726f6c6c657200 004861636b725333454c6162436f6e74726f6c6c657200 $bin
        $binpatch $binpatch_flags 004170706c654e564d655265717565737454696d657200 004861636b724e564d655265717565737454696d657200 $bin
        $binpatch $binpatch_flags 004170706c654e564d6552657175657374506f6f6c00 004861636b724e564d6552657175657374506f6f6c00 $bin
        $binpatch $binpatch_flags 004170706c654e564d65534d41525455736572436c69656e7400 004861636b724e564d65534d41525455736572436c69656e7400 $bin
        $binpatch $binpatch_flags 004170706c65533358436f6e74726f6c6c657200 004861636b72533358436f6e74726f6c6c657200 $bin
    fi
fi

# show final md5 with class rename
if [[ $quiet -eq 0 || $rehabman -ge 2 ]]; then
    echo "md5 $bin (after class rename): `md5 -q $bin`"
fi

# fix Info.plist for Samsung 950 Pro NVMe, and new class/bundle names
plist=$patched/Contents/Info.plist

# change version #
pattern='s/(\d*\.\d*(\.\d*)?)/9\1/'
if [[ 0 -eq 1 ]]; then
replace=`$plistbuddy -c "Print :NSHumanReadableCopyright" $plist | perl -p -e $pattern`
$plistbuddy -c "Set :NSHumanReadableCopyright '$replace'" $plist
fi
replace=`$plistbuddy -c "Print :CFBundleGetInfoString" $plist | perl -p -e $pattern`
$plistbuddy -c "Set :CFBundleGetInfoString '$replace'" $plist
replace=`$plistbuddy -c "Print :CFBundleVersion" $plist | perl -p -e $pattern`
$plistbuddy -c "Set :CFBundleVersion '$replace'" $plist
replace=`$plistbuddy -c "Print :CFBundleShortVersionString" $plist | perl -p -e $pattern`
$plistbuddy -c "Set :CFBundleShortVersionString '$replace'" $plist

# set high IOProbeScore
/usr/libexec/PlistBuddy -c "Add ':IOKitPersonalities:GenericNVMeSSD:IOProbeScore' integer" $plist
/usr/libexec/PlistBuddy -c "Set ':IOKitPersonalities:GenericNVMeSSD:IOProbeScore' 8000" $plist

if [[ rename_class -eq 1 ]]; then
    $plistbuddy -c "Set :CFBundleIdentifier com.apple.hack.HackrNVMeFamily" $plist
    $plistbuddy -c "Set :CFBundleName HackrNVMeFamily" $plist
    $plistbuddy -c "Set :CFBundleExecutable HackrNVMeFamily" $plist
fi
$plistbuddy -c "Delete :IOKitPersonalities:AppleNVMeSSD" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:AppleS1XController" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:AppleS3ELabController" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:AppleS3XController" $plist >/dev/null 2>&1
if [[ rename_class -eq 1 ]]; then
    $plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:CFBundleIdentifier com.apple.hack.HackrNVMeFamily" $plist
    $plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IOClass HackrNVMeController" $plist
fi
$plistbuddy -c "Delete :IOKitPersonalities:GenericNVMeSSD:IONameMatch" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:GenericNVMeSSD:IOPCIClassMatch" $plist >/dev/null 2>&1
if [[ $use_class_match -eq 0 ]]; then
# use IONameMatch for specific vendor/device-id match
    # add known PCIe SSD device ids to IONameMatch
    $plistbuddy -c "Add :IOKitPersonalities:GenericNVMeSSD:IONameMatch array" $plist
    devidx=0
    for devid in ${devids[@]}; do
        $plistbuddy -c "Add :IOKitPersonalities:GenericNVMeSSD:IONameMatch:$devidx string" $plist
        $plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IONameMatch:$devidx $devid" $plist
        ((devidx++))
    done
else
# use IOPCIClassMatch for NVMe class-code
    # 0x010802 is class code for NVMe (class-code is 24bit at offset 0x09 in PCI config space)
    # 0x01 = BCC = mass storage controller
    # 0x08 = SCC = Non-Volatile Memory controller
    # 0x02 = PI = NVMe
    # translates to <02 08 01 00> in class-code in ioreg (intel order)
    # IOPCIClassMatch seems matches against 32-bit class-code + revision at offset 0x08
    # NVMeGeneric uses: 0x01080000&0xFFFF0000 (not sure why)
    # correct IOPCIClassMatch seems to be: 0x01080200&0xFFFFFF00
    $plistbuddy -c "Add :IOKitPersonalities:GenericNVMeSSD:IOPCIClassMatch string" $plist
    if [[ $spoof_class_code -eq 0 ]]; then
        $plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IOPCIClassMatch 0x01080200&0xFFFFFF00" $plist
    else
        $plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IOPCIClassMatch 0x0108ff00&0xFFFFFF00" $plist
    fi
fi

expected_md5=`$plistbuddy -c "Print :PatchedMD5" $config 2>&1`
if [[ "$expected_md5" == *"Does Not Exist"* ]]; then
    echo "WARNING: patch file \"$config\" has no PatchedMD5 entry, not comparing md5 values"
else
    patched_md5=`md5 -q $bin`
    if [[ "$patched_md5" == "$expected_md5" ]]; then
        echo "Patched MD5 matches expected MD5 entry ($expected_md5)"
    else
        echo "WARNING: Patched MD5 ($patched_md5) does not match expected MD5 ($expected_md5)"
        if [[ $override_md5 -eq 0 ]]; then
            rm -r $patched
            echo "ERROR: Patched MD5 does not match and --override not specified. Generated kext, $patched, deleted!"
            exit
        fi
    fi
fi

if [[ $rehabman -eq 1 ]]; then
    # disassemble result
    otool -tVj $bin >$disasm
    otool -tVj $unpatched/Contents/MacOS/IONVMeFamily >$orgdisasm
    diff $orgdisasm $disasm >$disasm.diff
    echo disassembly created: $disasm
fi
