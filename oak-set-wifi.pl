#!/usr/bin/perl

# DESCRIPTION
#   Configures WiFi settings for Oak
#
# USAGE
#   perl oak-set-wifi.pl SSID MODE PASSWORD
#
#   - 1) start Oak in config mode and connect to its AP
#   - 2) run this script
#
#   MODE
#   - one of: open wep-psk wep-shared wpa-aes wpa-tkip
#             wpa2-aes wpa2-aes-tkip wpa2-tkip
#
# EXAMPLE
#   perl oak-set-wifi.pl MyWiFi wpa2-aes qwerty123456
#
# REQUIREMENTS
#   - curl
#   - libcrypt-openssl-rsa-perl
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

use Crypt::OpenSSL::RSA;
use JSON                 qw( decode_json   );
use MIME::Base64         qw( encode_base64 );

# ======================================================================
# CONSTANTS

my %MODES = (
  'open'          => 0,
  'wep-psk'       => 1,
  'wep-shared'    => 0x8001,
  'wpa-tkip'      => 0x00200002,
  'wpa-aes'       => 0x00200004,
  'wpa2-tkip'     => 0x00400002,
  'wpa2-aes'      => 0x00400004,
  'wpa2-aes-tkip' => 0x00400006,
);

# ======================================================================
# MAIN

if (@ARGV != 3) {
  say "USAGE: $0 SSID MODE PASSWORD";
  exit 1;
}
my ($ssid, $mode, $password) = @ARGV;

# CHECK PASSWORD
if (length($password) > 64) {
  say "ERROR: Password is too long (over 64 characters)";
  exit 1;
}

# CHECK MODE
if (! exists $MODES{$mode}) {
  say "ERROR: Invalid mode";
  say "Possible modes: " . join(' ', sort keys %MODES);
  exit 1;
}

# GET DEVICE PUBLIC KEY
my $key_pem;
{
  my $json_str = `curl -q -s --connect-timeout 5 http://192.168.0.1/public-key`;
  my $json_decoded = decode_json($json_str);
  if (! exists $$json_decoded{'b'}) {
    say "ERROR: Failed to get device public key";
    exit 1;
  }

  my $key_der_hex = $$json_decoded{'b'};
  my $key_der     = pack 'H*', $key_der_hex;
  
  $key_pem =
    "-----BEGIN PUBLIC KEY-----\n" .
    encode_base64($key_der) .
    "-----END PUBLIC KEY-----\n";
}

# ENCRYPT PASSWORD
my $password_enc_hex;
if ($password ne '') {
  my $rsa = Crypt::OpenSSL::RSA->new_public_key($key_pem);
  $rsa->use_pkcs1_padding();
  my $password_enc = $rsa->encrypt($password);
  $password_enc_hex = unpack 'H*', $password_enc;
  die 'INTERNAL ERROR' unless length($password_enc_hex) == 256;
}

# 'sec' can't be last parameter, ',' is required after value
my $json = '{' .
  '"sec":'   . $MODES{$mode}     . ',' .
  '"ssid":"' . $ssid             . '",' .
  '"pwd":"'  . $password_enc_hex . '"' .
'}';

my $cmd =
  "curl -q -s -X POST -H 'Content-Type: application/json' -d '$json'" .
  " --connect-timeout 5" .
  " http://192.168.0.1/configure-ap";

my $result = `$cmd`;
if ($result ne '{"r":0}') {
  say "ERROR: POST failed, result is $result";
  exit 1;
}
