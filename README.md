<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright (c) 2014, Joyent, Inc.
-->

# sdc-sdc

This repository is part of the Joyent SmartDataCenter project (SDC).  For
contribution guidelines, issues, and general documentation, visit the main
[SDC](http://github.com/joyent/sdc) project page.


# Overview

The SDC headnode GZ has historically had a number of `sdc-*` tools in
"/opt/smartdc/bin" (e.g. sdc-vmapi, sdc-ldap). These live(d) in
usb-headnode.git. Because they are not installed via an image they
weren't upgradeable via SAPI. To support the later an 'sdc' core
zone (akin to the Manta 'ops') zone was created. This repo is it.


# Rules for commits

- If the commit is at all significant, then increment the patch
  version (in "package.json") and add an appropriate note to
  "CHANGES.md".

- `make check`

- Test by pushing local changes to a COAL or test HN and test:

        ./tools/rsync-to $HN
        ./tools/test-on $HN

  Or the shortcut for COAL:

        make coaltest    # NYI

