#!/bin/bash

#set -x

rehabman=0
quiet=1

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

# list of known PCIe SSDs
# pci144d,a802 = Samsung 950 Pro NVMe
# pci1987,5007 = Zotac Sonix PCIe 480gb
devids=("pci144d,a802" "pci1987,5007")
# devids only used if use_class_match=0
use_class_match=1

# assume patching system volume kext
unpatched=/System/Library/Extensions/IONVMeFamily.kext
config=NVMe_patches_$1.plist
patched=HackrNVMeFamily-$1.kext
disasm=HackrNVMeFamily-$1.s
orgdisasm=NVMeFamily-$1.s

if [[ $rehabman -eq 1 ]]; then
    unpatched=./unpatched/IONVMeFamily_$1.kext
fi

echo "Creating patched $patched"

rm -Rf $patched
cp -RX $unpatched $patched
bin=$patched/Contents/MacOS/HackrNVMeFamily
mv $patched/Contents/MacOS/IONVMeFamily $bin

expected_md5=`$plistbuddy -c "Print :VanillaMD5" $config 2>&1`
if [[ "$expected_md5" == *"Does Not Exist"* ]]; then
    echo "WARNING: patch file \"$config\" has no VanillaMD5 entry, not comparing md5 values"
else
    vanilla_md5=`md5 -q $bin`
    if [[ "$vanilla_md5" == "$expected_md5" ]]; then
        echo "Vanilla MD5 matches expected MD5 entry ($expected_md5)"
    else
        echo "WARNING: Vanilla MD5 ($vanilla_md5) does not match expected MD5 ($expected_md5)"
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

# rename internal class
if [[ $quiet -eq 0 ]]; then
    echo "Rename class from AppleNVMeController to HackrNVMeController"
fi
$binpatch $binpatch_flags 004170706c654e564d65436f6e74726f6c6c657200 004861636b724e564d65436f6e74726f6c6c657200 $bin

# show final md5 with class rename
if [[ $quiet -eq 0 || $rehabman -ge 2 ]]; then
    echo "md5 $bin (after class rename): `md5 -q $bin`"
fi

# fix Info.plist for Samsung 950 Pro NVMe, and new class/bundle names
plist=$patched/Contents/Info.plist
$plistbuddy -c "Set :CFBundleIdentifier com.apple.hack.HackrNVMeFamily" $plist
$plistbuddy -c "Set :CFBundleName HackrNVMeFamily" $plist
$plistbuddy -c "Set :CFBundleExecutable HackrNVMeFamily" $plist
$plistbuddy -c "Delete :IOKitPersonalities:AppleNVMeSSD" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:AppleS1XController" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:AppleS3ELabController" $plist >/dev/null 2>&1
$plistbuddy -c "Delete :IOKitPersonalities:AppleS3XController" $plist >/dev/null 2>&1
$plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:CFBundleIdentifier com.apple.hack.HackrNVMeFamily" $plist
$plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IOClass HackrNVMeController" $plist
$plistbuddy -c "Delete :IOKitPersonalities:GenericNVMeSSD:IONameMatch" $plist
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
    $plistbuddy -c "Set :IOKitPersonalities:GenericNVMeSSD:IOPCIClassMatch 0x01080200&0xFFFFFF00" $plist
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
    fi
fi

if [[ $rehabman -eq 1 ]]; then
    # disassemble result
    otool -tVj $bin >$disasm
    otool -tVj $unpatched/Contents/MacOS/IONVMeFamily >$orgdisasm
    diff $orgdisasm $disasm >$disasm.diff
    echo disassembly created: $disasm
fi
