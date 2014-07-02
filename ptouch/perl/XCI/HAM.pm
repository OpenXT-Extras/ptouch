#!/usr/bin/perl
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

package XCI::HAM;

use Digest::MD5;

my $code_str = "0123456789abcefghijknqrstuwxyz*@";
my @code = split( / */, $code_str );

sub add_bits($$$) {
    my ( $bs, $n, $wl ) = @_;
    for ( my $c = 1 << ( $wl - 1 ) ; $c ; $c >>= 1 ) {
        push @{$bs}, ( $n & $c ) ? 1 : 0;
    }
}

sub get_bits($$$) {
    my ( $bs, $n, $wl ) = @_;
    my $ret = 0;
    for ( my $c = 1 << ( $wl - 1 ) ; $c ; $c >>= 1 ) {
        $ret |= $bs->[ $n++ ] ? $c : 0;
    }
    return $ret;
}

sub add_hex_digits($$) {
    my ( $bs, $s ) = @_;

    $s =~ s/[^0-9A-Fa-f]//g;

    my @digits = split( / */, $s );

    foreach $digit (@digits) {
        $i = unpack( "C", pack( "h", $digit ) );
        add_bits( $bs, $i, 4 );
    }

}

sub add_code_symbols($$) {
    my ( $bs, $s ) = @_;

    $s =~ tr/A-Z/a-z/;
    $s =~ s/[^$code_str]//g;

    my @digits = split( / */, $s );

    foreach $digit (@digits) {
        $i = index( $code_str, $digit );
        add_bits( $bs, $i, 5 );
    }

}

sub checksum($$) {
    my ( $bs, $n ) = @_;

    if ( $n == 0 ) {
        $n = scalar @{$bs};
    }

    my $st    = pack( "C$n", @{$bs} );
    my $md5st = MD5->hash($st);
    my @ckar  = unpack( "CCCCCCCCCCCCCCCC", $md5st );
    return $ckar[1] & 0x1f;
}

sub repack($$$) {
    my ( $bs, $a, $b ) = @_;

    my $n = scalar @{$bs};
    my $i = int( ( $n + ( $b - 1 ) ) / $b ) * $b;

    my $s = $i - $n;

    if ( $s >= $a ) {
        $s = int( $s / $a ) * $a;
        my @prep = ();

        while ( $s-- ) {
            push @prep, 0;
        }
        @{$bs} = ( @prep, @{$bs} );
    }
    else {

        while ( $s-- ) {
            push @{$bs}, 0;
        }

    }

}

sub HAM($) {
    my ($hex) = @_;
    my @bits  = ();
    my $ret   = "";

    add_hex_digits( \@bits, $hex );

    repack( \@bits, 4, 5 );

    my $ck = checksum( \@bits, 0 );

    add_bits( \@bits, $ck, 5 );

    for ( my $i = 0 ; $i < scalar @bits ; $i += 5 ) {
        $ret .= $code[ get_bits( \@bits, $i, 5 ) ];
    }

    return $ret;

}

sub UNHAM($) {
    my ($ham) = @_;
    my @bits  = ();
    my $ret   = "";

    add_code_symbols( \@bits, $ham );

    if ( scalar @bits < 5 ) {
        return undef;
    }

    my $cck = checksum( \@bits, scalar @bits - 5 );
    my $ock = get_bits( \@bits, scalar @bits - 5, 5 );

    if ( $cck != $ock ) {
        return undef;
    }

    my $n = int( ( scalar @bits - 5 ) / 4 ) * 4;

    for ( my $i = 0 ; $i < $n ; $i += 4 ) {
        $ret .= unpack( "h", pack( "C", get_bits( \@bits, $i, 4 ) ) );
    }

    return $ret;

}

1;

