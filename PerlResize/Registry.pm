package PerlResize::Registry;

use PerlResize;
use Carp;

use strict;
use warnings FATAL => 'all';
no warnings qw(redefine);

our $VERSION = '1.0';
use base qw(ModPerl::Registry);

our $saved_error;

sub handler {
        my $class = (@_ >= 2) ? shift : __PACKAGE__;
        my $r = shift;

        my $rc = $class->new($r)->default_handler();
        if ($rc != Apache2::Const::OK) {
                $r->status($rc);
        }

        return Apache2::Const::OK;
}

sub run {
        my ($self, @args) = (@_);
        my $rc = undef;

	# TODO: Fix
        #Billig::module_init();
        #{
        #        $saved_error = undef;
        #        local $SIG{__DIE__} = sub {
        #                $saved_error = Carp::longmess("" . $_[0]);
        #                die;
        #        };
        #        return $self->SUPER::run(@args);
        #}
}

sub error_check {
        my $self = shift;

        # ModPerl::Util::exit() throws an exception object whose rc is
        # ModPerl::EXIT
        # (see modperl_perl_exit() and modperl_errsv() C functions)
        if ($@ && !(ref $@ eq 'APR::Error' && $@ == ModPerl::EXIT)) {
                my $msg = $@;
                $msg = $saved_error if (defined($saved_error));

		# TODO: Fix
                #Billig::error_handler($msg, 1);

                # Apache insists on quoting these for us, so here goes
                for (split /\n/, $msg) {
                        s/\t/        /;
                        $self->log_error($_);
                }

                return Apache2::Const::SERVER_ERROR;
        }
        return Apache2::Const::OK;
}

1;

