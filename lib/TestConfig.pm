package TestConfig;

our %netftp_cfg = 
    (Debug => 1, Timeout => 120);

our %common_cfg =    
    (
     User => 'anonymous',           # overwrite anonymous USER default
     Host => 'ftp.k-r-nel.org',         # overwrite ftp.microsoft.com HOST default
     Pass => 'tbone@cpan.org',      # overwrite list@rebol.com PASS default
     RemoteDir  => '/pub',                   # overwrite slash DIR default
     Type => 'I'                    # (binary) TYPE default
     );

our %usc_cfg =    
    (
     User => 'anonymous',           # overwrite anonymous USER default
     Host => 'lnc.usc.edu',         # overwrite ftp.microsoft.com HOST default
     Pass => 'tbone@cpan.org',      # overwrite list@rebol.com PASS default
     RemoteDir  => '/pub',                   # overwrite slash DIR default
     Type => 'I'                    # (binary) TYPE default
     );


1;
