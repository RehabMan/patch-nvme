## NVMe patching script by RehabMan

This script can be used to create patched IONVMeFamily.kext for non-Apple NVMe SSDs, such as the Samsung 950 Pro NVMe.

The scripts implement the patches created by Pike R. Alpha and Mork vom Ork at Pike's blog.

See these links for background:

https://pikeralpha.wordpress.com/2016/06/20/stock-apple-nvmefamily-kext-is-a-go/

https://pikeralpha.wordpress.com/2016/06/27/nvmefamily-kext-bin-patch-data/

https://pikeralpha.wordpress.com/2016/06/29/nvmefamily-kext-bin-patch-data-for-el-capitan/

http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/


As I wrote on insanelymac.com:

"Although I'm generally a fan of Clover KextsToPatch, in this case I do not think it is the appropriate solution. In the normal case of a failed KextsToPatch, the kext in question just doesn't load, doesn't work, or causes panic. In the case of a failed KextsToPatch in this case, the result could be a partially patched kext, which could cause data loss. I will be installing a patched kext on my system instead of using Clover patches. The problem is the danger is great if only a portion of the patches apply to an updated system kext. In that case, the kext may load... and appear to work, but corrupt the volume due to the patch being incomplete (because of changes in the update). In that case, it would be better to use the old patched kext until a new patched kext can be created. The way I'm doing it on my system, I rename the class and bundle identifier (with additional patches) such that the patched kext can be installed alongside (in /L/E or /S/L/E, or injected) the unpatched vanilla kext."

The script here implements the strategy proposed above.


### Special patches for LiteOn/Plextor/Hynix NVMe

Read here: http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/page-42#entry2356251

Also, read here as Pene has proposed an alternate patch: https://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/?do=findComment&comment=2617639

The various patch selections are in config_patches.plist


### Special note regarding 4k block size capable drives

It may be that your drive is capable of being driven with a 4k block size instead of 512 bytes.  If the drive is in 4k mode, you may be able to use the IONVMeFamily.kext without patches.

Read here: https://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/?do=findComment&comment=2377304
A partial list of drives supporting 4k native:
- Toshiba XG3 (Controller: TC58NCP070GSB)
- OCZ RD400 (Controller: TC58NCP070GSB)
- Intel SSD750 (Have Performance/Speed Issues)
- WD Black (Controller: Marvell 88SS1093)

### 10.13 High Sierra

With 10.13, Apple has fixed their IONVMeFamily.kext and now it supports 512 byte block sizes natively.  This means for many NVMe SSDs, you do not need these patches.  Still, the special patches for LiteOn/Plextor/Hynix SSDs may be necessary (see above).


### 10.12 Sierra Notes

With 10.12 there are a couple of procedural changes:

- If you are trying to use HackrNVMeFamily for the 10.12 installer, forget about it.  Use the correct patches in config.plist KextsToPatch.

- Once you install, you can create the HackrNVMeFamily and use it (or use one you already created), but you must remove IONVMeFamily.kext from /System/Library/Extensions

I will update here when/if there is a better solution.

### 10.12 UPDATE

By tricking the system, we can prevent IONVMeFamily.kext from loading.  It involves injecting a fake "class-code" such that the IOPCIClassMatch in IONVMeFamily's Info.plist no longer matches.

With this technique, HackrNVMeFamily and IONVMeFamily can co-exist.  Applies to installation scenarios and to post-install.

See here for further details:
http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/page-29#entry2322636

Or here:
https://www.tonymacx86.com/threads/guide-hackrnvmefamily-co-existence-with-ionvmefamily-using-class-code-spoof.210316/

Note: The --spoof option to patch_nvme.sh can be used to automatically generate the kext with the modified IOPCIClassMatch.

Such as:
```
./patch_nvme.sh --spoof 10_12_2
```

And the --unpatched option can be used to specify an alternate location for the IONVMeFamily.kext.  For example, if you wanted to patch from a different version, or from an IONVMeFamily.kext that is stored somewhere else:
```
./patch_nvme.sh --unpatched /Volumes/10.11.6/System/Library/Extensions/IONVMeFamily.kext 10_11_6_sec2017-001
```


### A note about dual-boot and 10.13

If you're using the class-code spoof on versions prior to 10.13 (eg. 10.11 or 10.12), you will notice the spoofed class-code will prevent the IONVMeFamily.kext in 10.13 from loading.  And you will also notice there are no files in this project for patching 10.13 IONVMeFamily.kext.  That is because the 10.13 IONVMeFamily can now deal with 512 byte blocks natively, so there is no need to patch.

But with the class-code spoof in place, IONVMeFamily.kext from 10.13 will not load (it is looking for NVMe standard class-code).  For the non-dual boot scenario (eg. just booting 10.13, no other macOS/OS X versions), you can simply remove the class-codes spoof (SSDT_NVMe-Pcc.aml).

For the case of booting 10.11/10.12 + 10.13, install HackrNVMeFamilyInjector.kext to the system volume (10.13+ only).  It is a simple injector kext that adds the spoofed class-code to the IO catalog, causing IONVMeFamily.kext to load for the spoofed class-code.  That way HackrNVMeFamily-*.kext can be used for 10.12/10.11 and IONVMeFamily.kext (native) can be used on 10.13.


### Usage:

Download the ZIP (and extract it) or make a clone of the git repository.

Contents:
- patch_nvme.sh: main patching script
- NVMe_patches_10_11_5.plist: KextsToPatch content as provided by Mork vom Ork, post #33 IM thread.
- NVMe_patches_10_11_6_beta4.plist: KextsToPatch content as provided by Mork vom Ork, post #16 IM thread.
- NVMe_patches_10_11_6.plist: KextsToPatch content for 10.11.6 final
- NVMe_patches_10_11_6_sec2016-001: KextsToPatch content for 10.11.6 with security update 2016-001 (only md5 changed)
- NVMe_patches_10_11_6_sec2016-002: KextsToPatch content for 10.11.6 with security update 2016-002 (only md5 changed)
- NVMe_patches_10_11_6_sec2016-003: KextsToPatch content for 10.11.6 with security update 2016-003 (only md5 changed)
- NVMe_patches_10_11_6_supp2016-003: KextsToPatch content for 10.11.6 with security update (supplemental) 2016-003 (only md5 changed)
- NVMe_patches_10_11_6_sec2017-002: KextsToPatch content for 10.11.6 build 15G1510 (only md5 changed)
- NVMe_patches_10_11_6_sec2017-003: KextsToPatch content for 10.11.6 build 15G1611 (only md5 changed)
- NVMe_patches_10_11_6_sec2017-004: KextsToPatch content for 10.11.6 security update 2017-004 (only md5 changed)
- NVMe_patches_10_11_6_sec2017-005-15G18013.plist: KextsToPatch content for 10.11.6 security update 2017-005 (15G18013) (only md5 changed)
- NVMe_patches_10_11_6_sec2018-002.plist: KextsToPatch content for 10.11.6 security update 2018-002 (15G20015)
- NVMe_patches_10_11_6_sec2018-003.plist: KextsToPatch content for 10.11.6 security update 2018-003 (15G21013)
- NVMe_patches_10_11_6_sec2018-004.plist: KextsToPatch content for 10.11.6 security update 2018-004 (build # not known)
- NVMe_patches_10_11_6_15G22010.plist: KextsToPatch content for 10.11.6 security update 2018-??? (15G22010)
- NVMe_patches_10_12_dp1.plist: KextsToPatch content as provided by Mork vom Ork, post #8 IM thread.
- NVMe_patches_10_12_0.plist: KextsToPatch content for 10.12.0
- NVMe_patches_10_12_1_16B2555.plist: KextsToPatch content for 10.12.1 build 16B2555, which was followed up very quicky with an update.  The patches are the same as NVMe_patches_10_12_1.plist, but the MD5 sums are different.
- NVMe_patches_10_12_1.plist: KextsToPatch content for 10.12.1
- NVMe_patches_10_12_2.plist: KextsToPatch content for 10.12.2 (16C67)
- NVMe_patches_10_12_3.plist: KextsToPatch content for 10.12.3 (16D32)
- NVMe_patches_10_12_4.plist: KextsToPatch content for 10.12.4
- NVMe_patches_10_12_5.plist: KextsToPatch content for 10.12.5
- NMVe_Patches_10_12_6.plist: KextsToPatch content for 10.12.6
- NMVe_Patches_10_12_6_sec2017-001.plist: KextsToPatch content for 10.12.6 security update 2017-001 (16G1036)
- NMVe_Patches_10_12_6_sec2017-002.plist: KextsToPatch content for 10.12.6 security update 2017-002 (16G1114)
- NVMe_Patches_10_12_6_sec2018-001.plist: KextsToPatch content for 10.12.6 security update 2018-001 (16G1212)
- NVMe_Patches_10_12_6_sec2018-002.plist: KextsToPatch content for 10.12.6 security update 2018-002 (16G1314)
- NVMe_Patches_10_12_6_sec2018-003.plist: KextsToPatch content for 10.12.6 security update 2018-003 (16G1408)
- NVMe_Patches_10_12_6_sec2018-004.plist: KextsToPatch content for 10.12.6 security update 2018-004 (16G1510)
- NVMe_Patches_10_12_6_sec2018-005.plist: KextsToPatch content for 10.12.6 security update 2018-005 (16G1618)
- NVMe_Patches_10_12_6_sec2018-006.plist: KextsToPatch content for 10.12.6 security update 2018-006 (16G1710)
- NVMe_Patches_10_12_6_sec2019-001.plist: KextsToPatch content for 10.12.6 security update 2019-001 (16G1815)
- binpatch: pre-built utility to patch binary files using a simple command line.
- binpatch.c: source for binpatch binary
- config_patches.plist: contains _DSM to XDSM ACPI patch, and other special purpose (LiteOn/Plextor/Hynix) IONVMeFamily patches
- HackrNVMeFamilyInjector.kext: for 10.13 with class-code spoof in place.  See above "A note about dual-boot and 10.13"

Usage:
- extract patch_nvme.zip archive
- cd to the extracted location
- execute patch_nvme.sh with argument that corresponds to the plist you wish to patch with
- the script creates the patched kext in the current directory
- you must run the script with the parameter that corresponds to the version of OS X you are running
- /System/Library/Extensions/IONVMeFamily.kext must be vanilla

For example, if you are running 10.11.5, and had downloaded/extracted patch-nvme-master from github, to create a patched 10.11.5 kext:
```
cd ~/Downloads/patch-nvme-master
./patch_nvme.sh 10_11_5
```

I tend to use git as it was intended:
```
mkdir ~/Projects && cd Projects
git clone https://github.com/RehabMan/patch-nvme.git patch-nvme.git
cd patch-nvme.git
./patch_nvme.sh 10_11_5
```

The result is HackrNVMeFamily-10_11_5.kext. You can install it to /S/L/E, /L/E, or use Clover kext injection with it. It will not interfere with IONVMeFamily.kext and system updates will not change it.

You can also leave the patch name unspecified, and the script will determine the correct patch based on the vanilla IONVMeFamily:
```
./patch_nvme.sh
```

Or with --spoof option:
```
./patch_nvme.sh --spoof
```

You should also make sure you have no patches for IONVMeFamily.kext in your config.plist before trying to use the patched kext.

Note: The current script uses class-code matching with IOPCIClassMatch to match against any NVMe compliant SSD.



### Feedback:

Feedback here: http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/page-3#entry2247453

Use "Issues" at github for reporting bugs.



### Change Log:

2017-04-19

- added automatic detection of correct patch file if patch name is unspecified

- added additional error checking (will not generate a patched kext when md5 sums do not match, unless --override is specified)

- added --override (advanced use only)


2017-04-03

- added --unpatched option (joevt)


2017-03-29

- added support for 10.11.6 security update 2017-001


2017-03-28

- added support for 10.12.4


2017-01-23

- added support for 10.12.3



2016-07-04

- changed to using IOPCIClassMatch instead of IONameMatch


2016-07-03

- orignal release on insanelymac.com

