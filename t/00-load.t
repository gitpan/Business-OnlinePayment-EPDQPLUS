#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Business::OnlinePayment::EPDQPLUS' ) || print "Bail out!\n";
}

diag( "Testing Business::OnlinePayment::EPDQPLUS $Business::OnlinePayment::EPDQPLUS::VERSION, Perl $], $^X" );
