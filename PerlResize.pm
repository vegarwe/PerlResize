package PerlResize;

#
# Script that resize and cache images based on input.
#
# e.g. http://media.host/path/img.jpg?geometry=<width>x<height>
#
# Author: Vegar Westerlund <vegarwe@gmail.com>
#
# Thanks to adamcik@samfundet.no
#

use strict;
use warnings;
use HTTP::Date;
use APR::Table;
use File::stat;
use Image::Magick;
use File::Basename qw(fileparse);
use Apache2::Const -compile => qw(:common HTTP_NOT_MODIFIED HTTP_METHOD_NOT_ALLOWED);

our $max_size = 5000;
our $cache = "/var/www/abakus.no/app/files/cache/";

sub handler {
	my $r = shift; 

	#$r->log_error("PerlResize");
	#$r->log_error("  content_type: ".$r->content_type());
	#$r->log_error("  filename:     ".$r->filename);
	#$r->log_error("  path_info:    ".$r->path_info);
	#$r->log_error("  args:         ".$r->args);
	#$r->log_error("  finfo         ".$r->finfo);

	# Must be image, with cusom geometry and read permissions must be granted
	return Apache2::Const::DECLINED unless $r->content_type() =~ m#^image/.*$#;
    	return Apache2::Const::DECLINED unless $r->args;
	return Apache2::Const::DECLINED unless -r $r->filename;

	my ($file, $args, $cfile, $stat, $cstat, $modified_since);

	$file = $r->filename;
	$r->args =~ m#geometry=(\d+)x(\d+)#;
	if ($1 > $max_size || $2 > $max_size) {
		# TODO: Send '405 Method Not Allowed', "Size $1x$2 out of max range"
  		$r->log_error("Size ($1x$2) out of max range");
		$r->custom_response(Apache2::Const::HTTP_METHOD_NOT_ALLOWED, "<h1>405 Method Not Allowed</h1><p>Size ($1x$2) out of max range</p>");
  		return Apache2::Const::HTTP_METHOD_NOT_ALLOWED;
	}
	$args = "$1x$2";
	my ($name,$path,$suffix) = File::Basename::fileparse($file, '\.\w+');
	$cfile = $path;
	$cfile =~ s#/#_#g;
	$cfile = "$cache/$cfile$name-$args$suffix";

	$stat = File::stat::stat($file);

	$modified_since = $r->headers_in->get('If-Modified-Since');
	$modified_since = HTTP::Date::str2time($modified_since);
	if (defined $modified_since && $modified_since >= $stat->mtime) {
		$r->log_error("not modified");
        	return Apache2::Const::HTTP_NOT_MODIFIED;
	}

	$cstat = File::stat::stat($cfile);

	if (defined $cstat && defined $stat && $cstat->mtime > $stat->mtime) {
		$r->log_error("cache hit");
		$r->mtime($stat->mtime);
		$r->headers_out->set('Last-Modified' => HTTP::Date::time2str($stat->mtime));
		$r->sendfile($cfile);
        	return Apache2::Const::OK;
	}

	my $q = Image::Magick->new;
	my $err = $q->Read($file);
	if ($q->Get('Colorspace') eq "CMYK") {
		$err ||= $q->Set(colorspace=>'RGB');
	}

	$err ||= $q->Resize(geometry => $args);
	$err ||= $q->Strip();
	$err ||= $q->Write(filename => $cfile);

    	if ($err) {
    	    $r->log_error($err);
    	    return Apache2::Const::SERVER_ERROR;
    	}

	$r->log_error("cache miss");
	$r->mtime($stat->mtime);
	$r->headers_out->set('Last-Modified' => HTTP::Date::time2str($stat->mtime));
	$r->sendfile($cfile);
        return Apache2::Const::OK;
}

1;
