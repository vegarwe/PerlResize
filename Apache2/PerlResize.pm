package Apache2::PerlResize;

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
use APR::Table;
use File::stat;
use Image::Magick;
use File::Basename qw(fileparse);
use Apache2::Const -compile => qw(:common HTTP_NOT_MODIFIED HTTP_METHOD_NOT_ALLOWED);

use Apache2::Overload;

our $max_size = 5000;
our $cache = "/var/cache/apache2/mod_perl_resize";

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

    # If we are in overload mode (aka Slashdot mode), refuse to generate
    if (Apache2::Overload::is_in_overload($r)) {
        $r->log->warn("In overload mode, not scaling " . $r->filename);
        return Apache2::Const::DECLINED;
    }

    my ($file, $args, $cfile, $stat, $cstat);

    $file = $r->filename;
    $r->args =~ m#geometry=(\d+)x(\d+)#;
    if ($1 > $max_size || $2 > $max_size) {
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

    $r->set_last_modified($stat->mtime);

    # If the client can use cache, by all means do so
    if ((my $rc = $r->meets_conditions) != Apache2::Const::OK) {
        $r->log_error("not modified");
        return $rc;
    }

    $cstat = File::stat::stat($cfile);

    if (!defined $cstat || $cstat->mtime < $stat->mtime) {
        $r->log_error("cache miss");

        my $q = Image::Magick->new;
        my $err = $q->Read($file);
        if ($q->Get('Colorspace') eq "CMYK") {
            $err ||= $q->Set(colorspace=>'RGB');
        }

        $err ||= $q->Resize(geometry => $args);
        $err ||= $q->Strip(); # Strip EXIF tags
        $err ||= $q->Write(filename => $cfile);
        undef $q;

        if ($err) {
            $r->log_error($err);
            return Apache2::Const::SERVER_ERROR;
        }
    } else {
        $r->log_error("cache hit");
    }

    #$r->set_content_length($stat->size);
    $r->sendfile($cfile);
    return Apache2::Const::OK;
}

1;
