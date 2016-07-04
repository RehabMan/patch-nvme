## NVMe patching script by RehabMan

### Usage:

Download the ZIP (and extract it) or make a clone of the git repository.

Contents:
- patch_nvme.sh: main patching script
- NVMe_patches_10_11_5.plist: KextsToPatch content as provided by Mork vom Ork, post #33 this thread.
- NVMe_patches_10_11_6_beta4.plist: KextsToPatch content as provided by Mork vom Ork, post #16 this thread.
- NVMe_patches_10_12_dp1.plist: KextsToPatch content as provided by Mork vom Ork, post #8 this thread.
- binpatch: pre-built utility to patch binary files using a simple command line.
- binpatch.c: source for binpatch binary

Usage:
- extract patch_nvme.zip archive
- cd to the extracted location
- execute patch_nvme.sh with argument that corresponds to the plist you wish to patch with
- the script creates the patched kext in the current directory
- you must run the script with the parameter that corresponds to the version of OS X you are running
- /System/Library/Extensions/IONVMeFamily.kext must be vanilla

For example, if you are running 10.11.5, to create a patched 10.11.5 kext:
```
cd ~/Downloads/patch_nvme
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

