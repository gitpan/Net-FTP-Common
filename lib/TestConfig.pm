package TestConfig;

our %netftp_cfg = 
    (Debug => 1, Timeout => 120);

our %common_cfg =    
    (
     User => 'anonymous',           # overwrite anonymous USER default
     Host => 'ftp.fcc.gov',         # overwrite ftp.microsoft.com HOST default
     Pass => 'tbone@cpan.org',      # overwrite list@rebol.com PASS default
     RemoteDir  => '/',                   # overwrite slash DIR default
     Type => 'I'                    # (binary) TYPE default
     );


1;
