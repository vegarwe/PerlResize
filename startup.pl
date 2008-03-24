# Standard mod_perl startup.pl -- load most common required modules

use Bundle::Apache2 ();
use lib qw(
        /etc/apache2/perl
);

use Apache::DBI;

# use ModPerl::Util (); #for CORE::GLOBAL::exit

use Apache2::Const -compile => ':common';
use APR::Const -compile => ':common';

1;
