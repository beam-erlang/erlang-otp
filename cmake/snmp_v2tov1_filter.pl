# SPDX-License-Identifier: Apache-2.0
# Portable equivalent of the retained bin/snmp-v2tov1.sed substitutions.
use strict;
use warnings;
binmode STDOUT;
while (<>) {
    # sed's pattern space excludes the line terminator.
    my $ending = s/\n\z// ? "\n" : "";
    s/Integer32/INTEGER/g;
    s/Counter32/Counter/g;
    s/Gauge32/Gauge/g;
    s/MAX-ACCESS/ACCESS    /g;
    s/OBJECTS/VARIABLES/g;
    s/current[^a-zA-Z0-9]/mandatory/g;
    s/current$/mandatory/g;
    s/accessible-for-notify/not-accessible/g;
    s/read-create/read-write/g;
    print $_, $ending;
}
