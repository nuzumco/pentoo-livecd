#!/bin/sh
source /tmp/envscript

fix_locale() {
	grep -q "en_US ISO-8859-1" /etc/locale.nopurge || echo en_US ISO-8859-1 >> /etc/locale.nopurge
	grep -q "en_US.UTF-8 UTF-8" /etc/locale.nopurge || echo en_US.UTF-8 UTF-8 >> /etc/locale.nopurge
	sed -i -e '/en_US ISO-8859-1/s/^# *//' -e '/en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen || /bin/bash
	locale-gen || /bin/bash
	eselect locale set en_US.utf8 || /bin/bash
}

fix_locale

#revdep-rebuild --library 'libstdc++.so.6' -- --buildpkg=y --usepkg=n --exclude gcc

emerge -1kb --newuse --update sys-apps/portage || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

emerge -1 -kb wgetpaste || /bin/bash

#ease transition to the new use flags
USE="-directfb" emerge -1 -kb libsdl DirectFB || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#finish transition to the new use flags
emerge --deep --update --newuse -kb @world || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#fix interpreted stuff
perl-cleaner --all -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#first we set the python interpreters to match PYTHON_TARGETS
PYTHON2=$(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 1 |sed 's#_#.#')
PYTHON3=$(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 2 |sed 's#_#.#')
eselect python set --python2 ${PYTHON2} || /bin/bash
eselect python set --python3 ${PYTHON3} || /bin/bash
${PYTHON2} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON2#python}
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON3#python}
if [ -x /usr/sbin/python-updater ];then
	python-updater -- --buildpkg=y || /bin/bash
fi

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

emerge -1 -kb app-portage/gentoolkit || /bin/bash

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y || /bin/bash

/usr/local/portage/scripts/bug-461824.sh

#some things fail in livecd-stage1 but work here, nfc why
USE="aufs symlink" emerge -1 -kb sys-kernel/pentoo-sources || /bin/bash
#emerge -1 -kb app-crypt/johntheripper || /bin/bash

#fix java circular deps in next stage
emerge --update --oneshot -kb icedtea-bin:8 || /bin/bash
eselect java-vm set system icedtea-bin-8 || /bin/bash
emerge --update --oneshot -kb icedtea:8 || /bin/bash
emerge -C icedtea-bin:8 || /bin/bash
eselect java-vm set system icedtea-8 || /bin/bash

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#add 64 bit toolchain to 32 bit iso to build dual kernel iso
[ "$(uname -m)" = "x86" ] && crossdev -s1 -t x86_64

eclean-pkg
emerge --depclean || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash
