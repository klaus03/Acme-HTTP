package Acme::HTTP;

use strict;
use warnings;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw();
our @EXPORT_OK = qw();
our $VERSION   = '0.05';

use Net::HTTP::NB;
use Net::HTTPS::NB;

our $MaxIt;
$MaxIt = 3 unless defined $MaxIt;

our $TimeOut;
$TimeOut = 10 unless defined $TimeOut;

sub new {
    my $self = shift;
    my ($url) = @_;
    my $hdl;

    our $Code = -1;
    our $Message = '?';
    our %Response = ();

    our $Real_Url = '';
    our $Iter = 0;

    while (defined $url) {
        $Iter++;
        if ($Iter > $MaxIt) {
            $@ = 'Acme::HTTP - Runaway iterations ('.$MaxIt.')';
            return;
        }

        $Real_Url = $url;

        my ($type, $host, $get) =
          $Real_Url =~ m{\A ([^:]+) : // ([^/]+)        \z}xms ? ($1, $2, '/') :
          $Real_Url =~ m{\A ([^:]+) : // ([^/]+) (/ .*) \z}xms ? ($1, $2, $3)  :
          do {
            $@ = 'Acme::HTTP - Invalid structure)';
            return;
          };

        my $net_http =
          $type eq 'http'  ? 'Net::HTTP::NB'  :
          $type eq 'https' ? 'Net::HTTPS::NB' :
          do { 
            $@ = 'Acme::HTTP - Can\'t identify type';
            return;
          };

        $hdl = $net_http->new(Host => $host) or do {
            $@ = 'Acme::HTTP - Can\'t Net::HTTP(S)->new(Host =>...)';
            return;
        };

        $hdl->write_request(GET => $get, 'User-Agent' => 'Mozilla/5.0');

        use IO::Select;
        my $sel = IO::Select->new($hdl);
 
        READ_HEADER: {
            unless ($sel->can_read($TimeOut)) {
                $@ = 'Acme::HTTP - Header timeout('.$TimeOut.')';
                return;
            }

            ($Code, $Message, %Response) = $hdl->read_response_headers;

            redo READ_HEADER unless $Code;
        }

        $url = $Response{'Location'};
    }

    unless (defined $hdl) {
        $@ = 'Acme::HTTP - Internal error, hdl is undefined';
        return;
    }

    return $hdl;
}

1;

__END__

=head1 NAME

Acme::HTTP - High-level access to Net::HTTP and Net::HTTPS

=head1 SYNOPSIS

    use Acme::HTTP;

    # you can use http:
    my $url = "http://perldoc.perl.org/perlfaq5.html";

    # ...or, alternatively, use https:
    #  $url = "https://metacpan.org/pod/Data::Dumper";

    $Acme::HTTP::MaxIt   =  3; # Number of redirections
    $Acme::HTTP::TimeOut = 10; # TimeOut in seconds

    my $obj = Acme::HTTP->new($url) || die $@;

    if ($Acme::HTTP::Code eq '404') {
        die "Page '$url' not found";
    }
    elsif ($Acme::HTTP::Code ne '200') {
        die "Page '$url' - Error $Acme::HTTP::Code, ".
          "Msg '$Acme::HTTP::Message'";
    }

    print "Orig url   = ", $url, "\n";
    print "Real url   = ", $Acme::HTTP::Real_Url, "\n";
    print "Iterations = ", $Acme::HTTP::Iter, "\n";
    print "Length     = ", $Acme::HTTP::Response{'Content-Length'} // 0, "\n";
    print "\n";

    use IO::Select;
    my $sel = IO::Select->new($obj);

    while (1) {
        # we allow 15 seconds before timeout
        die "Body timeout" unless $sel->can_read(15);

        my $n = $obj->read_entity_body(my $buf, 4096);
        die "read failed: $!" unless defined $n;
        last unless $n;

        print $buf;
    }

=head1 VARIABLES

The following variables are available read-only after new():

=over

=item $Acme::HTTP::Code

=item $Acme::HTTP::Message

=item %Acme::HTTP::Response

=item $Acme::HTTP::Real_Url

=item $Acme::HTTP::Iter

=back

=head2 List of values

In case of a successful read, the variables $Acme::HTTP::Code and
$Acme::HTTP::Message are usually set as follows:

  $Acme::HTTP::Code    => '200'
  $Acme::HTTP::Message => 'OK'

However, a non-existing address would typically return different values:

  $Acme::HTTP::Code    => '404'
  $Acme::HTTP::Message => 'Not Found'

Here is one sample result of %Acme::HTTP::Response of an MP3 file:

  'Content-Type'   => 'audio/mpeg'
  'Content-Length' => '28707232'
  'Date'           => 'Sun, 17 Aug 2014 10:53:43 GMT'
  'Last-Modified'  => 'Thu, 10 Jul 2014 04:52:52 GMT'
  'Accept-Ranges'  => 'bytes'
  'Connection'     => 'close'

  'Cache-Control'  => 'max-age=2269915'
  'ETag'           => '"1404967972"'
  'X-HW'           => '1408272823.dop...pa1.c'

...and here is another example result of %Acme::HTTP::Response of a Web page:

  'Content-Type'   => 'text/html; charset=utf-8'
  'Content-Length' => '31569'
  'Date'           => 'Sun, 17 Aug 2014 11:02:54 GMT'
  'Last-Modified'  => 'Thu, 24 Jul 2014 03:31:45 GMT'
  'Accept-Ranges'  => 'bytes'
  'Connection'     => 'close'

  'Age'            => '0'
  'Set-Cookie'     => '...expires=12-Sep-2031...; secure',
  'Server'         => 'nginx/0.7.67',
  'Vary'           => 'Accept-Encoding,Cookie'
  'Via'            => '1.1 varnish',
  'X-Cache'        => 'MISS, MISS',
  'X-Cache-Hits'   => '0, 0',
  'X-Runtime'      => '0.479137'
  'X-Served-By'    => 'cache-lo80-LHR, cache-fra1222-FRA',

=head1 AUTHOR

Klaus Eichner <klaus03@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Klaus Eichner

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms of the artistic license 2.0,
see http://www.opensource.org/licenses/artistic-license-2.0.php

=cut
