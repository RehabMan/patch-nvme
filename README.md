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
- NVMe_patches_10_12_dp1.plist: KextsToPatch content as provided by Mork vom Ork, post #8 IM thread.
- NVMe_patches_10_12_0.plist: KextsToPatch content for 10.12.0
- NVMe_patches_10_12_1_16B2555.plist: KextsToPatch content for 10.12.1 build 16B2555, which was followed up very quicky with an update.  The patches are the same as NVMe_patches_10_12_1.plist, but the MD5 sums are different.
- NVMe_patches_10_12_1.plist: KextsToPatch content for 10.12.1
- NVMe_patches_10_12_2.plist: KextsToPatch content for 10.12.2 (16C67)
- NVMe_patches_10_12_3.plist: KextsToPatch content for 10.12.3 (16D32)
- binpatch: pre-built utility to patch binary files using a simple command line.
- binpatch.c: source for binpatch binary
- config_patches.plist: contains _DSM to XDSM ACPI patch

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

You should also make sure you have no patches for IONVMeFamily.kext in your config.plist before trying to use the patched kext.

Note: The current script uses class-code matching with IOPCIClassMatch to match against any NVMe compliant SSD.



### Feedback:

Feedback here: http://www.insanelymac.com/forum/topic/312803-patch-for-using-nvme-under-macos-sierra-is-ready/page-3#entry2247453

Use "Issues" at github for reporting bugs.



### Change Log:

2016-07-04

- changed to using IOPCIClassMatch instead of IONameMatch

2016-07-03

- orignal release on insanelymac.com

