#!/usr/bin/env perl 
#
# Copyright (c) 2014 Citrix Systems, Inc.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

#

use strict;
use GD;
use XCI::HAM;
use Barcode::Code128;
use GD::Barcode::QRcode;
use GD::Text;
use GD::Text::Align;
use Data::Dumper;

sub blit($$$$) {
    my ( $d, $x, $y, $s ) = @_;

    my $w = $s->width;
    my $h = $s->height;

    $d->{rect}->[0] = $x if $d->{rect}->[0] > $x;
    $d->{rect}->[1] = $y if $d->{rect}->[1] > $y;

    $d->{rect}->[2] = $x + $w if $d->{rect}->[2] < ( $x + $w );
    $d->{rect}->[3] = $y + $h if $d->{rect}->[3] < ( $y + $h );

    $d->{gdi}->copy( $s, $x, $y, 0, 0, $w, $h );
}

sub new_dest() {
    my $im = new GD::Image( 1000, 1000 );
    my $white = $im->colorAllocate( 255, 255, 255 );
    $im->filledRectangle( 0, 0, $im->width, $im->height, $white );

    return { gdi => $im, rect => [ $im->width, $im->height, 0, 0 ] };
}

sub spit($) {
    my $d = shift;

    my $x = $d->{rect}->[0];
    my $y = $d->{rect}->[1];
    my $w = $d->{rect}->[2] - $x;
    my $h = $d->{rect}->[3] - $y;

    my $ow = $w + 10;

    $ow += 7;
    $ow = $ow & ~0x7;

    my $out = new GD::Image( $ow, 10 + $h );

    my $white = $out->colorAllocate( 255, 255, 255 );
    $out->filledRectangle( 0, 0, $out->width, $out->height, $white );
    $out->copy( $d->{gdi}, 5, 5, $x, $y, $w, $h );

    print $out->png;

}

sub try_size($$$) {
    my ( $align, $s, $t ) = @_;

    $align->set_font( 'TODO download Vera.ttf fonts, they are free and available on the webs', $s );
    $align->set_text($t);
    my @q = ( $align->bounding_box( 100, 100, 0 ) );

    return ( $q[6], $q[7], $q[4] - $q[0], $q[3] - $q[7] );
}

sub get_text($$) {
    my ( $t, $tw ) = @_;

    my $gd = GD::Image->new( 1000, 1000 );
    my $white = $gd->colorAllocate( 255, 255, 255 );
    my $black = $gd->colorAllocate( 0,   0,   0 );
    $gd->filledRectangle( 0, 0, $gd->width, $gd->height, $white );

    my $align = GD::Text::Align->new(
        $gd,
        valign => 'top',
        halign => 'left',
        color  => $black
    );

    my ( $x, $y, $w, $h );

    my $s = 0;
    do {
        $s++;
        ( $x, $y, $w, $h ) = try_size( $align, $s, $t );
    } while ( $w < $tw );
    $s--;

    ( $x, $y, $w, $h ) = try_size( $align, $s, $t );

    $align->draw( 100, 100, 0 );

    #print $gd->png;
    #die;

    my $ret = GD::Image->new( $w, $h );

    $ret->copy( $gd, 0, 0, $x, $y, $w, $h );

    return $ret;
}

my $y = 0;
my $x = 0;

#my $hex = sprintf( "%08x", $ARGV[0] );

my $id = $ARGV[0]; # "L" . XCI::HAM::HAM($hex);

my $im = new_dest();

my $code = new Barcode::Code128;
$code->option( "scale",     4 );
$code->option( "show_text", 0 );
my $code128 = $code->gd_image($id);
blit( $im, 0, 0, $code128 );

$y = $code128->height + 10;

my $qrcode = GD::Barcode::QRcode->new( 'http://a.xci-test.com/' . $id,
    { Ecc => 'Q', ModuleSize => 6 , Version => 3  } )->plot;

blit( $im, 0, $y, $qrcode );
$x = $qrcode->width + 10;

my $text = get_text( $id, 650 - $x );
blit( $im, $x, $y + 20, $text );

spit($im);

