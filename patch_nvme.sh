#!/bin/bash

#set -x

rehabman=0

if [[ ! -e NVMe_patches_$1.plist ]]; then
    echo "Error: NVMe_patches_$1.plist does not exist!"
    exit
fi

binpatch=./binpatch
if [[ ! -e $binpatch ]]; then
    cc -o binpatch binpatch.c
fi
if [[ ! -e $binpatch ]]; then
    echo "Error: $binpatch does not exist... cannot binary patch!"
    exit
fi
plistbuddy=/usr/libexec/PlistBuddy

# device-id of Samsung 950 Pro NVMe
devid=pci144d,a802

# assume patching system volume kext
unpatched=/System/Library/Extensions/IONVMeFamily.kext
config=NVMe_patches_$1.plist
patched=HackrNVMeFamily-$1.kext
disasm=HackrNVMeFamily-$1.s

if [[ $rehabman -eq 1 ]]; then
    if [[ $1 == "10_12_dp1" ]]; then
        unpatched=/Volumes/10.12.dp/System/Library/Extensions/IONVMeFamily.kext
    fi
fi

echo "Creating patched $patched"

rm -Rf $patched
cp -RX $unpatched $patched
bin=$patched/Contents/MacOS/HackrNVMeFamily
mv $patched/Contents/MacOS/IONVMeFamily $bin

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
    printf "Comment: %s\n" "$comment"
    find=`$plistbuddy -x -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Find" $config 2>&1`
    repl=`$plistbuddy -x -c "Print :KernelAndKextPatches:KextsToPatch:$patch:Replace" $config`
    find=$([[ "$find" =~ \<data\>(.*)\<\/data\> ]] && echo ${BASH_REMATCH[1]})
    repl=$([[ "$repl" =~ \<data\>(.*)\<\/data\> ]] && echo ${BASH_REMATCH[1]})
    find=`echo $find | base64 --decode | xxd -p | tr '\n' ' '`
    repl=`echo $repl | base64 --decode | xxd -p | tr '\n' ' '`
    $binpatch "$find" "$repl" $bin
done

# show md5 with just normal patches from Pike
echo md5 $bin: `md5 -q $bin`
if [[ $rehabman -eq 1 ]]; then
    echo md5 frompike/IONVMeFamily_10115_Step_2: `md5 -q frompike/IONVMeFamily_10115_Step_2`
    echo md5 frompike/IONVMeFamily_WORKS_Step_9_Y: `md5 -q frompike/IONVMeFamily_WORKS_Step_9_Y`
fi

# rename internal class
echo "Rename class from AppleNVMeController to HackrNVMeController"
$binpatch 004170706c654e564d65436f6e74726f6c6c657200 004861636b724e564d65436f6e74726f6c6c657200 $bin

# show final md5 with class rename
echo md5 $bin: `md5 -q $bin`

# fix Info.plist for Samsung 950 Pro NVMe, and new class/bundle names
plist=$patched/Contents/Info.plist
$plistbuddy -c "Set :CFBundleIdentifier com.apple.hack.HackrNVMeFamily" $plist
$plistbuddy -c "Set :CFBundleName HackrNVMeFamily" $plist
$plistbuddy -c "Set :CFBundleExecutable HackrNVMeFamily" $plist
$plistbuddy -c "Delete :IOKitPersonalities:AppleNVMeSSD" $plist
$plistbuddy -c "Delete :IOKitPersonalities:AppleS1XController" $plist
$plistbuddy -c "Delete :IOKitPersonalities:AppleS3ELabController" $plist
$plistbuddy -c "Delete :IOKitPersonalities:AppleS3XController" $plist
$plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:CFBundleIdentifier com.apple.hack.HackrNVMeFamily" $plist
$plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IOClass HackrNVMeController" $plist
$plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IONameMatch:0 $devid" $plist

if [[ $rehabman -eq 1 ]]; then
    # disassemble result
    otool -tVj $bin >$disasm
    echo disassembly created: $disasm
fi
