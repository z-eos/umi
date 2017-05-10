# -*- mode: cperl -*-
#

package UMI::Form::SearchAdvanced;

use Data::Printer;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP'; with 'Tools'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

sub build_form_element_class { [ 'form-horizontal', ] }

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

has '+action' => ( default => '/searchadvanced/proc' );

has_field 'search_history'
  => ( type => 'Checkbox',
       # checkbox_value => '0',
       label => 'search history',
       wrapper_class => [ 'checkbox', ],
       element_wrapper_class => [ 'col-xs-3', 'col-xs-offset-2', 'col-lg-1', ],
       element_attr => { title => 'When checked, this checkbox causes additional fields to search by in history.',}, );

has_field 'base_dn'
  => ( label => 'Base DN',
       label_class => [ 'col-md-2' ],
       wrapper_class => [ 'searchaccount', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => UMI->config->{ldap_crud_db},
			 title => q{The DN that is the base object entry relative to which the search is to be performed.}, }, );

has_field 'reqType'
  => ( type => 'Select',
       label => 'reqType',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       empty_select => '--- cn=umilog search type ---',
       options => [{ value => 'add', label => 'add'},
		   { value => 'modify', label => 'modify'},
		   { value => 'delete', label => 'delete'}, ], );

has_field 'reqAuthzID'
  => ( label => 'reqAuthzID',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
       element_attr => { placeholder => 'uid=ACTION-REQUESTED-BY,ou=People,dc=' . UMI->config->{ldap_crud_db_log},
			 title => 'The reqAuthzID attribute is the distinguishedName of the user that performed the operation. This will usually be the same name as was established at the start of a session by a Bind request (if any) but may be altered in various circumstances.',},	);

has_field 'reqDn'
  => ( label => 'reqDn',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
       element_attr => { placeholder => 'uid=ACTION-REQUESTED-ON,ou=People,dc=' . UMI->config->{ldap_crud_db},
			 title => 'The reqDN attribute is the distinguishedName of the target of the operation. E.g., for a Bind request, this is the Bind DN. For an Add request, this is the DN of the entry being added. For a Search request, this is the base DN of the search.',}, );

has_field 'reqMod'
  => ( type => 'TextArea',
       label => 'Request Mod',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => '*uid:+*john.doe*    or    *physicalDeliveryOfficeName:=*ou=borg,*',
			 title => 'reqType add: *uid:+*john.goe*;    reqType modify: *physicalDeliveryOfficeName:= ou=borg,*;    reqType delete: has no reqMod'},
       rows => 1 );

has_field 'reqMessage'
  => ( type => 'TextArea',
       label => 'reqMessage',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => 'Password is in history of old passwords',
			 title => 'An error code may be accompanied by a text error message which will be recorded in the reqMessage attribute.',},
       rows => 1 );

has_field 'reqResult'
  => ( type => 'Select',
      label => 'reqResult',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       empty_select => '--- LDAP code ---',
       element_attr => { title => 'The reqResult attribute is the numeric LDAP result code of the operation, indicating either success or a particular LDAP error code.',}, );

sub options_reqResult {
  return (
	  0 => '0 - LDAP_SUCCESS',
	  1 => '1 - LDAP_OPERATIONS_ERROR',
	  2 => '2 - LDAP_PROTOCOL_ERROR',
	  3 => '3 - LDAP_TIMELIMIT_EXCEEDED',
	  4 => '4 - LDAP_SIZELIMIT_EXCEEDED',
	  5 => '5 - LDAP_COMPARE_FALSE',
	  6 => '6 - LDAP_COMPARE_TRUE',
	  7 => '7 - LDAP_AUTH_METHOD_NOT_SUPPORTED',
	  7 => '7 - LDAP_STRONG_AUTH_NOT_SUPPORTED',
	  8 => '8 - LDAP_STRONG_AUTH_REQUIRED',
	  9 => '9 - LDAP_PARTIAL_RESULTS',
	  10 => '10 - LDAP_REFERRAL',
	  11 => '11 - LDAP_ADMIN_LIMIT_EXCEEDED',
	  12 => '12 - LDAP_UNAVAILABLE_CRITICAL_EXT',
	  13 => '13 - LDAP_CONFIDENTIALITY_REQUIRED',
	  14 => '14 - LDAP_SASL_BIND_IN_PROGRESS',
	  16 => '16 - LDAP_NO_SUCH_ATTRIBUTE',
	  17 => '17 - LDAP_UNDEFINED_TYPE',
	  18 => '18 - LDAP_INAPPROPRIATE_MATCHING',
	  19 => '19 - LDAP_CONSTRAINT_VIOLATION',
	  20 => '20 - LDAP_TYPE_OR_VALUE_EXISTS',
	  21 => '21 - LDAP_INVALID_SYNTAX',
	  32 => '32 - LDAP_NO_SUCH_OBJECT',
	  33 => '33 - LDAP_ALIAS_PROBLEM',
	  34 => '34 - LDAP_INVALID_DN_SYNTAX',
	  35 => '35 - LDAP_IS_LEAF',
	  36 => '36 - LDAP_ALIAS_DEREF_PROBLEM',
	  47 => '47 - LDAP_PROXY_AUTHZ_FAILURE',
	  48 => '48 - LDAP_INAPPROPRIATE_AUTH',
	  49 => '49 - LDAP_INVALID_CREDENTIALS',
	  50 => '50 - LDAP_INSUFFICIENT_ACCESS',
	  51 => '51 - LDAP_BUSY',
	  52 => '52 - LDAP_UNAVAILABLE',
	  53 => '53 - LDAP_UNWILLING_TO_PERFORM',
	  54 => '54 - LDAP_LOOP_DETECT',
	  60 => '60 - LDAP_SORT_CONTROL_MISSING',
	  61 => '61 - LDAP_INDEX_RANGE_ERROR',
	  64 => '64 - LDAP_NAMING_VIOLATION',
	  65 => '65 - LDAP_OBJECT_CLASS_VIOLATION',
	  66 => '66 - LDAP_NOT_ALLOWED_ON_NONLEAF',
	  67 => '67 - LDAP_NOT_ALLOWED_ON_RDN',
	  68 => '68 - LDAP_ALREADY_EXISTS',
	  69 => '69 - LDAP_NO_OBJECT_CLASS_MODS',
	  70 => '70 - LDAP_RESULTS_TOO_LARGE',
	  71 => '71 - LDAP_AFFECTS_MULTIPLE_DSAS',
	  76 => '76 - LDAP_VLV_ERROR',
	  80 => '80 - LDAP_OTHER',
	  81 => '81 - LDAP_SERVER_DOWN',
	  82 => '82 - LDAP_LOCAL_ERROR',
	  83 => '83 - LDAP_ENCODING_ERROR',
	  84 => '84 - LDAP_DECODING_ERROR',
	  85 => '85 - LDAP_TIMEOUT',
	  86 => '86 - LDAP_AUTH_UNKNOWN',
	  87 => '87 - LDAP_FILTER_ERROR',
	  88 => '88 - LDAP_USER_CANCELED',
	  89 => '89 - LDAP_PARAM_ERROR',
	  90 => '90 - LDAP_NO_MEMORY',
	  91 => '91 - LDAP_CONNECT_ERROR',
	  92 => '92 - LDAP_NOT_SUPPORTED',
	  93 => '93 - LDAP_CONTROL_NOT_FOUND',
	  94 => '94 - LDAP_NO_RESULTS_RETURNED',
	  95 => '95 - LDAP_MORE_RESULTS_TO_RETURN',
	  96 => '96 - LDAP_CLIENT_LOOP',
	  97 => '97 - LDAP_REFERRAL_LIMIT_EXCEEDED',
	  118 => '118 - LDAP_CANCELED',
	  119 => '119 - LDAP_NO_SUCH_OPERATION',
	  120 => '120 - LDAP_TOO_LATE',
	  121 => '121 - LDAP_CANNOT_CANCEL',
	  122 => '122 - LDAP_ASSERTION_FAILED',
	  4096 => '4096 - LDAP_SYNC_REFRESH_REQUIRED',
	 );
}

has_field 'reqOld'
  => ( type => 'TextArea',
       label => 'Request Old',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => '*mail: ass2kick@borg.startrek.in*' },
       rows => 1 );

has_field 'reqStart'
  => ( label => 'Request Start Time',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       element_attr => { placeholder => '20141104142246.000014Z' }, );

has_field 'reqEnd'
  => ( label => 'Request End Time',
       label_class => [ 'col-md-2', ],
       wrapper_class => [ 'searchhistory', ],
       element_wrapper_class => [ 'col-xs-5', 'col-lg-2', ],
       element_attr => { placeholder => '20141104142356.000007Z' }, );

has_field 'search_filter'
  => ( type => 'TextArea',
       label => 'Search Filter',
       label_class => [ 'col-md-2', 'required' ],
       wrapper_class => [ 'searchaccount', ],
       element_wrapper_class => [ 'col-xs-10', 'col-lg-10', ],
       element_attr => { placeholder => '(objectClass=*)',
			 title => q{A filter that defines the conditions an entry in the directory must meet in order for it to be returned by the search. It is a string. Values inside filters may need to be escaped to avoid security problems.}, },
			 rows => 1, );

has_field 'show_attrs' => ( label => 'Show Attributes',
			    label_class => [ 'col-md-2' ],
			    element_wrapper_class => [ 'col-xs-10', 'col-lg-5', ],
			    element_attr => { placeholder => 'cn, uid, mail, authorizedService',
					      title => q{A list of attributes to be returned for each entry that matches the search filter.

If not specified, then the server will return the attributes that are specified as accessible by default given your bind credentials.

Certain additional attributes may also be available for the asking: createTimestamp }, });

has_field 'order_by' => ( label => 'Order By',
			  label_class => [ 'col-md-2' ],
			  wrapper_class => [ 'searchaccount', ],
			  element_wrapper_class => [ 'col-xs-5', 'col-lg-5', ],
			  element_attr => { placeholder => 'cn',
					    title => q{A list of attributes, result objects to be sorted by. }, }, );

has_field 'search_results' => ( label => 'Search Results',
				label_class => [ 'col-md-2' ],
				element_wrapper_class => [ 'col-xs-3', 'col-lg-2', ],
				element_attr => { placeholder => '50',
						  title => q{A sizelimit that restricts the maximum number of entries to be returned as a result of the search. A value of 0, means that no restriction is requested.}, },);

has_field 'search_scope' => ( type => 'Select',
			      label => 'Search Scope',
			      label_class => [ 'col-md-2' ],
			      label_attr => { title => 'The scope in which to search', },
			      wrapper_class => [ 'searchaccount', ],
			      element_wrapper_class => [ 'col-xs-3', 'col-lg-2', ],
			      element_attr => { title => q{BASE:
search only the base object.

ONE:
search the entries immediately below the base object.

SUB and SUBTREE:
search the whole tree below (and including) the base object. this is the default.

CHILDREN:
search the whole subtree below the base object, excluding the base object itself.},
					      },
			      options => [{ value => 'sub', label => 'Sub', selected => 'on'},
					  { value => 'children', label => 'Children'},
					  { value => 'one', label => 'One'},
					  { value => 'base', label => 'Base'},
					 ],
			    );

has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-4' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block' ],
			   element_wrapper_class => [ 'col-xs-12', ],
		         );

has_field 'aux_submit' => ( type => 'Submit',
			    wrapper_class => [ 'col-md-8' ],
			    element_class => [ 'btn', 'btn-success', 'btn-block' ],
			    value => 'Submit' );

# working sample
# sub validate_givenname {
#   my ($self, $field) = @_;
#   unless ( $field->value ne 'Вася' ) {
#     $field->add_error('Such givenName+sn+uid user exists!');
#   }
# }

sub validate {
  my $self = shift;

  if ( $self->field('search_history')->value eq '1' &&
       $self->field('reqAuthzID')->value eq '' &&
       $self->field('reqDn')->value eq '' &&
       $self->field('reqEnd')->value eq '' &&
       $self->field('reqMessage')->value eq '' &&
       $self->field('reqMod')->value eq '' &&
       $self->field('reqOld')->value eq '' &&
       $self->field('reqResult')->value eq '' &&
       $self->field('reqStart')->value eq '' &&
       $self->field('reqType')->value eq '' ) {
    $self->field('reqAuthzID')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqDn')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqEnd')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqMessage')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqMod')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqOld')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqResult')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqStart')->add_error('Filter is mandatory, you have entered no any!');
    $self->field('reqType')->add_error('Filter is mandatory, you have entered no any!');
    #$self->add_form_error('Filter is mandatory, you have entered no any!');
  }
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;
