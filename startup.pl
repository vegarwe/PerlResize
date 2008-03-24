# Standard mod_perl startup.pl -- load most common required modules

use Bundle::Apache2 ();

# TODO: These should be fixed with 'use Bundle::Apache2 ();', but it doesn't
use Apache2::Log;
use Apache2::Response ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();

use Apache2::Const -compile => ':common';
use APR::Const -compile => ':common';

use lib qw(
        /etc/apache2/perl
);

1;
