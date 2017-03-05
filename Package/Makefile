# Makefile for RansomWhere related tasks

# to use:
# make path=/path/2/ransomware.app target

# to check signatures
#pkgutil --check-signature /path/to/.pkg 
#codesign -dvvv /path/to/.dmg

PKGTITLE="RansomWhere"
PKGVERSION="1.1.0"
PKGID=com.objective-see.ransomwhere
PROJECT="RansomWhere"
PB_EXTRA_ARGS+= --sign "Developer ID Installer: Objective-See, LLC (VBG97UB4TA)"

#################################################

##Help - Show this help menu
help: 
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

##  clean - Clean up temporary working directories
clean:
	rm -f ./RansomWhere*.{dmg,pkg}
	rm -fr pkgroot

##  copy - Copy resources from .app to proper directories
copy:
	mkdir -p pkgroot/Library/{RansomWhere,LaunchDaemons}/
	cp $(path)/Contents/Resources/RansomWhere pkgroot/Library/RansomWhere/
	cp $(path)/Contents/Resources/alertIcon.png pkgroot/Library/RansomWhere/
	cp $(path)/Contents/Resources/graylist.plist pkgroot/Library/RansomWhere/
	cp $(path)/Contents/Resources/whitelist.plist pkgroot/Library/RansomWhere/
	cp $(path)/Contents/Resources/com.objective-see.ransomwhere.plist pkgroot/Library/LaunchDaemons/


##  pkg - Create a package using pkgbuild
pkg: clean copy
	pkgbuild --root pkgroot --scripts scripts --identifier ${PKGID} ${PB_EXTRA_ARGS} --version ${PKGVERSION} --ownership recommended ./${PKGTITLE}_${PKGVERSION}.pkg

##  dmg - Wrap the package inside a dmg
dmg: pkg
	rm -f ./${PROJECT}*.dmg
	rm -rf /tmp/${PROJECT}-build
	mkdir -p /tmp/${PROJECT}-build/
	cp -R ./${PKGTITLE}_${PKGVERSION}.pkg /tmp/${PROJECT}-build
	hdiutil create -srcfolder /tmp/${PROJECT}-build -volname "${PROJECT}" -format UDZO -o ${PROJECT}_${PKGVERSION}.dmg
	codesign -s "Developer ID Application: Objective-See, LLC (VBG97UB4TA)" -v ${PROJECT}_${PKGVERSION}.dmg
	rm -rf /tmp/${PROJECT}-build