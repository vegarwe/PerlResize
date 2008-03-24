package PerlResize;

#
# Script that resize and cache images based on input.
#
# e.g. http://media-host/resize.pl/<widgth>x<height>/path/img.jpg
#
# Author: Vegar Westerlund <vegarwe@gmail.com>
#
# Thanks to adamcik@samfundet.no
#

use strict;
use warnings;
use Image::Magick;
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw();
use MIME::Types;
use File::stat;
use IO::File;
use HTTP::Date;
use File::Basename qw(fileparse);

our $max_size = 5000;
our $cache = "/var/www/testlab.abakus.ntnu.no/cache";

sub handler {
	my $r = shift; 

	my ($file, $args, $cfile, $stat, $cstat);

	$r->log_error("PerlResize");
	$r->log_error("  content_type: ".$r->content_type());
	$r->log_error("  filename:     ".$r->filename);
	$r->log_error("  path_info:    ".$r->path_info);
	$r->log_error("  args:         ".$r->args);
	$r->log_error("  finfo         ".$r->finfo);

	# Must be image, with cusom geometry and read permissions must be granted
	return Apache2::Const::DECLINED unless $r->content_type() =~ m#^image/.*$#;
    	return Apache2::Const::DECLINED unless $r->args;
	return Apache2::Const::DECLINED unless -r $r->filename;

	$file = $r->filename;
	$r->args =~ m#geometry=(\d+)x(\d+)#;
	if ($1 > $max_size || $2 > $max_size) {
		# TODO: Send '405 Method Not Allowed', "Size $1x$2 out of max range"
  		$r->log_error("Size ($1x$2) out of max range");
  		return Apache2::Const::SERVER_ERROR;
	}
	$args = "$1x$2";
	my ($name,$path,$suffix) = File::Basename::fileparse($file, '\.\w+');
	$cfile = $path;
	$cfile =~ s#/#_#g;
	$cfile = "$cache/$cfile$name-$args$suffix";

	$stat = File::stat::stat($file);

	# TODO: Fix $ENV
	#$r->log_error("ENV: " . $ENV);
	#my $modified_since = HTTP::Date::str2time($ENV{HTTP_IF_MODIFIED_SINCE});
	#if (defined $modified_since && $modified_since > $stat->mtime) {
	#	$r->log_error("not modified");
	#	#print "Status: 304 Not Modified\n\n" ;
        #	return Apache2::Const::DECLINED;
	#}

	$cstat = File::stat::stat($cfile);

	if (defined $cstat && defined $stat && $cstat->mtime > $stat->mtime) {
		$r->log_error("cache hit");
		$r->sendfile($cfile);
        	return Apache2::Const::OK;
	}

	$r->log_error("cache miss");

	my $q = Image::Magick->new;
	my $err = $q->Read($file);
	if ($q->Get('Colorspace') eq "CMYK") {
		$q->Set(colorspace=>'RGB');
	}

	#my (%arguments) = $r->args;
	#$err ||= $q->Resize(%arguments);
	$err ||= $q->Resize(geometry => $args);
	$err ||= $q->Strip();
	$err ||= $q->Write(filename => $cfile);

    	if ($err) {
    	    $r->log_error($err);
    	    return Apache2::Const::SERVER_ERROR;
    	}

	$r->sendfile($cfile);
        return Apache2::Const::OK;
}

1;
