#!/usr/bin/perl

# DESCRIPTION
#   Configures Oak for local server,
#   setting server IP or DOMAIN and public key.
#
# USAGE
#   perl oak-set-server.pl IP_OR_DOMAIN PUBLIC_KEY_FILE
#
#   - 1) start Oak in config mode and connect to its AP
#   - 2) run this script
#
#   IP_OR_DOMAIN
#   - server IP address or domain name
#
#   PUBLIC_KEY_FILE
#   - server keyfile in PEM format
#     - usually default_key.pub.pem inside particle-server directory
#
# EXAMPLE
#   perl oak-set-server.pl 192.168.11.28 /home/pi/particle-server/default_key.pub.pem
#
# REQUIREMENTS
#   - curl
#   - openssl
#   - libjson-perl
#
# LICENSE
#   Copyright (c) 2016 Markus Laire
#
#   Permission is hereby granted, free of charge, to any person
#   obtaining a copy of this software and associated documentation files
#   (the "Software"), to deal in the Software without restriction,
#   including without limitation the rights to use, copy, modify, merge,
#   publish, distribute, sublicense, and/or sell copies of the Software,
#   and to permit persons to whom the Software is furnished to do so,
#   subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be
#   included in all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#   OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
#   ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
#   THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

use v5.20;
use warnings FATAL => 'all';
use JSON qw( decode_json );

if (@ARGV != 2) {
  say "USAGE: $0 IP_OR_DOMAIN PUBLIC_KEY_FILE";
  exit 1;
}

my ($ip_or_domain, $key_file) = @ARGV;

if (! -e $key_file) {
  say "ERROR: File $key_file doesn't exist.";
  exit 1;
}

# convert key to DER-format, and then hex-encode it
my $key_der = `openssl rsa -in $key_file -pubin -outform DER 2>/dev/null`;
my $key_der_hex = unpack 'H*', $key_der;

my $address_type = ($ip_or_domain =~ /^\d+\.\d+\.\d+\.\d+$/) ? 0 : 1;

my $json = '{' .
  '"server-address":"'     . $ip_or_domain . '",' .
  '"server-address-type":' . $address_type . ','  .
  '"server-public-key":"'  . $key_der_hex  . '"'  .
'}';

my $cmd =
  "curl -q -s -X POST -H 'Content-Type: application/json' -d '$json'" .
  " --connect-timeout 5" .
  " http://192.168.0.1/set";

my $result = `$cmd`;
if ($result ne '{"r":0}') {
  say "ERROR: POST failed, result is $result";
  exit 1;
}
