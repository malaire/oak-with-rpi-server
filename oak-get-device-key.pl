#!/usr/bin/perl

# DESCRIPTION
#   Gets device public key from Oak and saves it to given directory,
#   named as <DEVICE_ID>.pub.pem
#   - Output directory is created if it doesn't exist
#   - File is overwritten if it exists
#
# USAGE
#   perl oak-get-device-key.pl OUTPUT_DIR
#
#   - 1) start Oak in config mode and connect to its AP
#   - 2) run this script
#
# EXAMPLE
#   perl oak-get-device-key.pl /home/pi/particle-server
#
# REQUIREMENTS
#   - curl
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

if (@ARGV != 1) {
  say "USAGE: $0 OUTPUT_DIR";
  exit 1;
}
my ($output_dir) = @ARGV;

# GET DEVICE ID
my $id;
{
  my $json_str = `curl -q -s --connect-timeout 5 http://192.168.0.1/device-id`;
  my $json_decoded = decode_json($json_str);
  if (! exists $$json_decoded{'id'}) {
    say "ERROR: Failed to get device id";
    exit 1;
  }
  $id = $$json_decoded{'id'};
}

# GET DEVICE PUBLIC KEY
# - TODO: Should the filename have '.pub.der' extension ?
my $key;
{
  my $json_str = `curl -q -s --connect-timeout 5 http://192.168.0.1/public-key`;
  my $json_decoded = decode_json($json_str);
  if (! exists $$json_decoded{'b'}) {
    say "ERROR: Failed to get device public key";
    exit 1;
  }

  my $key_hex = $$json_decoded{'b'};
  $key = pack 'H*', $key_hex;
}

# SAVE KEY TO FILE
mkdir $output_dir unless -e $output_dir;
my $output_file = "$output_dir/$id.pub.pem";
my $fh;
if (! open($fh, '>', $output_file)) {
  say "ERROR: Can't create file $output_file";
  exit 1;
}
print $fh $key;
close $fh;
