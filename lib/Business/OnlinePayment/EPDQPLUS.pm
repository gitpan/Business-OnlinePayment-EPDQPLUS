package Business::OnlinePayment::EPDQPLUS;

=head1 NAME

Business::OnlinePayment::EPDQPLUS - Barclaycard EPDQplus API Direct Link

=head1 DESCRIPTION

This module provides access to the Barclaycard EPDQplus Direct Link API and documented in v4.3.3 of the
Barclay Integration guide.

It is currently a work in progress.

To use/test this module you will need:
 PSPID - Barclaycard supplied credential
 "admin" user for the api with password (login and password) in the Barclaycard backend as per the online help.
 Optional SHA signing secret defined for API access

Currently implemented - "Normal Authorization" (Operation "SAL").

=head1 USAGE

use Business::OnlinePayment;

  my $tx = Business::OnlinePayment->new("EPDQPLUS");

  $tx->content(
      pspid          => 'see above',
      login          => 'added via Barclaycard Backoffice',
      password       => 'set via Barclaycard Backoffice'
      [shasign	     => 'set via Barclaycard Backoffice - choose SHA512 in Global Security settings',]
      [eci           => '0|1|2|3|4|7|9 typically 7 with CVC and 9 for recurring payments without CVC',

      action         => 'Normal Authorization',  
      description    => '20 English Roses',
      amount         => '49.95',
      currency       => 'USD',
      order_number   => 'ORDER0001',

      name           => 'B Obama',
      address        => 'Whitehouse, 1600 Pennsylvannia Road',

      city           => 'Washington DC',
      zip            => 'DC 20500',
      country        => 'US',
      phone          => '',

      card_number    => '5569510117486571',
      expiration     => '0515', # MMYY is a Barclay card format -- what does BOP expect
      cvv2            => '377',
  );

  $tx->submit();

  print "server_response = ", $tx->server_response, "\n";
  print "is_success      = ", $tx->is_success,      "\n";
  print "authorization   = ", $tx->authorization,   "\n";
  print "error_message   = ", $tx->error_message,   "\n\n";
  print "result_code     = ", $tx->result_code,     "\n";

=head1 AUTHOR

Simon Waters <simonw@zynet.net>

Derived from code by Jason Kohles and Ivan Kohler and Dan Helfman

=head1 Methods

=over 4

=item set_defaults()

Required by Business::OnlinePayment

=item submit()

Required by Business::OnlinePayment

=item test_transaction(1)

Required by Business::OnlinePayment

Call with 1 for Barclays test server
Call with 0 to reset to Barclays live server

=back

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-onlinepayment-epdqplus at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-OnlinePayment-EPDQPLUS>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SEE ALSO

perl(1). L<Business::OnlinePayment>

=cut

use base qw( Business::OnlinePayment::HTTPS );

use strict;
use warnings FATAL => 'all';

use Carp;
use Business::OnlinePayment::HTTPS;
use URI::Escape qw/uri_escape/;
use Digest::SHA qw/sha512_hex/;
use XML::Simple;

use vars qw($VERSION $DEBUG);

our $VERSION = '0.02';
our $DEBUG=0;

sub _info {
  {
    'info_compat'           => '0.01', # always 0.01 for now,
                                       # 0.02 will have requirements
    'gateway_name'          => 'Barclaycard EPDQ+ API Direct Link',
    'gateway_url'           => 'http://www.barclaycard.co.uk/business/accepting-payments/epdq-ecomm/extraplus/',
    'module_version'        => $VERSION,
    'supported_types'       => [ qw( CC ) ],
    'token_support'         => 0, #card storage/tokenization support
    'test_transaction'      => 1, #set true if ->test_transaction(1) works
    'supported_actions'     => [
                                 'Normal Authorization',
                               ],
  };
}

sub set_defaults {
    my $self = shift;

    $self->build_subs('failure_status') unless $self->can('failure_status');

    $self->server('payments.epdq.co.uk') unless $self->server; 
    $self->port('443') unless $self->port;
    $self->path('/ncol/prod/orderdirect.asp') unless $self->path; 
   
}

sub test_transaction {
    my ($self,$value) = @_;
    if ($value) {
     $self->server('mdepayments.epdq.co.uk');
     $self->path('/ncol/test/orderdirect.asp');
    } else {
     $self->server('payments.epdq.co.uk');
     $self->path('/ncol/prod/orderdirect.asp');
    }
}

sub _map_fields {
    my($self) = @_;

    my %content = $self->content();

    my %actions = ('normal authorization' => 'SAL', # Only one implemented
                   'authorization only'   => 'RES', # from Barclays docs 4.3.3
                   'credit'               => 'RFD', # from Barclays docs 4.3.3
                  );

    $content{'action'} = $actions{lc($content{'action'} || '')} || $content{'action'};

    my $amount = $content{'amount'};

    if ( $amount =~ /-?\d*\.\d\d/ ) { # Match a number with two decimal places
      $content{'amount'} = int(100*$amount);
    } else {
      croak "Invalid format for amount";
    }

    my $expiration = $content{'expiration'};

    if ( $expiration =~ /\d\d\/\d\d/ ) { # Transform MM/YY to MMYY
     $content{'expiration'} = substr($expiration,0,2).substr($expiration,3,2);
    } else {
     croak "Invalid expiration date format";
    }


    $self->content(%content);
}

sub submit {
    my($self) = @_;

    $self->_map_fields();
    $self->remap_fields(
	pspid		  => 'PSPID',
        login             => 'USERID',
        password          => 'PSWD',
	shasign		  => 'SHASIGN',
        action            => 'OPERATION',
        description       => 'COM',
        name		  => 'CN',
        amount            => 'AMOUNT', # Note Barclays expect this in cents or pence thus $13.23 is transformed to 1323 and £142.00 is 14200
        currency          => 'CURRENCY', # USD GBP EUR other - must have Multi-currency store with Barclays
	order_number      => 'ORDERID',
        customer_ip       => 'REMOTE_ADDR',
        address           => 'OWNERADDRESS',
        city              => 'OWNERTOWN',
        zip               => 'OWNERZIP',
        country           => 'OWNERCTY', # As ISO country code GB, US, etc
        ship_last_name    => 'ECOM_SHIPTO_POSTAL_NAME_LAST', # SHIPTO fields not yet tested
        ship_first_name   => 'ECOM_SHIPTO_POSTAL_NAME_FIRST',
        ship_company      => 'ECOM_SHIPTO_COMPANY',
        ship_address      => 'ECOM_SHIPTO_POSTAL_STREET_LINE1',
        ship_city         => 'ECOM_SHIPTO_POSTAL_CITY',
        ship_zip          => 'ECOM_SHIPTO_POSTAL_POSTCODE',
        ship_country      => 'ECOM_SHIPTO_POSTAL_COUNTRYCODE', # ISO country code GB, US, etc
        phone             => 'OWNERTELNO',
        email_customer    => 'EMAIL',
        card_number       => 'CARDNO',
        expiration        => 'ED',
        cvv2              => 'CVC',
        eci               => 'ECI',
    );

    my @required_fields = ( qw(pspid login password action amount currency card_number expiration) );

    $self->required_fields(@required_fields);

    my %post_data = $self->get_fields(qw/
      PSPID USERID PSWD 
      OPERATION COM CN AMOUNT CURRENCY ORDERID CARDNO ED CVC ECI
      REMOTE_ADDR 
      OWNERADDRESS OWNERTOWN OWNERZIP OWNERCTY OWNERTELNO EMAIL 
      ECOM_SHIPTO_POSTAL_NAME_LAST ECOM_SHIPTO_POSTAL_NAME_FIRST ECOM_SHIPTO_COMPANYi
      ECOM_SHIPTO_POSTAL_STREET_LINE1 ECOM_SHIPTO_POSTAL_CITY ECOM_SHIPTO_POSTAL_POSTCODE ECOM_SHIPTO_POSTAL_COUNTRYCODE
        /);

     # Compute a suitable SHA1 sum for the transaction.
     #
     my %content = $self->content();
     if ( $content{'SHASIGN'} ne '' ){
       
       my $SHATEXT;
       foreach my $key (sort keys %post_data) {
 	if ($post_data{$key} ne '') { 
      	  $SHATEXT.=$key."=".$post_data{$key}.$content{'SHASIGN'};
          print $key.": ".$post_data{$key}."\n" if $DEBUG;
        }

       }
       
  
       my $SHAHASH= uc(sha512_hex($SHATEXT));
  
       print "SHA TEXT IS $SHATEXT\n" if $DEBUG;
       print "Hash is $SHAHASH\n" if $DEBUG;
  
       $post_data{'SHASIGN'}=$SHAHASH; 
  
     }

   
    my $opt = {};

    my($page, $server_response, %headers) =
      $self->https_post( $opt, \%post_data );

    $self->server_response($page);
    $self->response_headers(%headers);

#??? IF SUCCEEDED

    my $result = XMLin($page);

    my $status=$result->{STATUS};
    my $ncerror=$result->{NCERROR};

    if ( $status eq 9 and $ncerror eq 0 ){
         
      $self->is_success(1);
      $self->result_code($result->{ACCEPTANCE});
      $self->authorization($result->{PAYID});

    } else {

      $self->is_success(0);
      $self->result_code($result->{ACCEPTANCE});
      $self->error_message("Failed: Status: $status, Error: $ncerror, Message:".$result->{NCERRORPLUS});

      $self->failure_status("declined");
    }

}

1;

