use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Net::FTP::Common',
    'VERSION_FROM'	=> 'Common.pm', # finds $VERSION
    'PREREQ_PM'		=> { Net::FTP => 0 }, # e.g., Module::Name => 1.1
);

print(<<EOF);
Important Notes!
---------------
Net::FTP::Common is built on top, and requires, Net::FTP.

Net::FTP is available from the libnet distribution on CPAN.

Please visit http://kobsearch.cpan.org or http://search.cpan.org
to obtain libnet and install that before installing Net::FTP::Common.

There is a mailing list at lists.perl.org that deals with Net::FTP and
the people there are relatively helpful. Another source is
comp.lang.perl.modules. But I would also be willing to help. However,
I am not a Net::FTP expert, so don't expect miracles :)

But of course for any issues with Net::FTP::Common, contact me
immediately please.
EOF

