DIST=patch_nvme
DIST_FILES=NVMe_patches*.plist binpatch binpatch.c patch_nvme.sh

all: binpatch

binpatch: binpatch.c
	cc -o binpatch binpatch.c

distribute: $(DIST_FILES)
	if [ -e ./Distribute ]; then rm -r ./Distribute; fi
	mkdir ./Distribute
	zip ./Distribute/`date +$(DIST)-%Y-%m%d.zip` $(DIST_FILES)

.PHONY: clean
clean:
	rm -f binpatch
	rm -Rf Hackr*.kext
	rm -Rf Distribute


