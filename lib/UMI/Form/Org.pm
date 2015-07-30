# -*- cperl -*-
#

package UMI::Form::Org;

use HTML::FormHandler::Moose;
extends 'UMI::Form::LDAP';

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{'class'}}, 'required'
    if $type eq 'label' && $field->required;
}

# bl-0 ----------------------------------------------------------------------

has_field 'aux_parent' => ( type => 'Select',
			    label => 'Parent Office',
			    wrapper_class => [ 'col-xs-6' ],
			    label_attr => { title => 'parent office, the one to be created belongs' },
			  );

=head2 options_aux_parent

returns array of hash refs { value => ... , label => ... } like:

'ou=foo,ou=Organizations,dc=ibs',
'foo (Foo @ City1)',
...
'ou=br04,ou=br03,ou=br02,ou=br01,ou=bar,ou=Organizations,dc=WeAre',
'br04 (Bar @ CityN) branch of  -> br03 -> br02 -> br01 -> bar'

=cut

sub options_aux_parent {
  my $self = shift;

  return unless $self->ldap_crud;

  my $ldap_crud = $self->ldap_crud;
  my $mesg = $ldap_crud->search(
				{
				 base => $ldap_crud->{'cfg'}->{'base'}->{'org'},
				 scope => 'children',
				 filter => 'ou=*',
				 attrs => [ qw(ou physicaldeliveryofficename l) ],
				 sizelimit => 0
				}
			       );
  my @orgs = ( { value => '0', label => '--- no parent office ---', selected => 'on' } );
  my @entries = $mesg->entries;
  my ( $a, $i, @dn_arr, $dn, $label );
  foreach my $entry ( @entries ) {
    @dn_arr = split(',',$entry->dn);
    if ( scalar @dn_arr < 4 ) {
      $label = sprintf("%s (head office %s @ %s)",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		      );
    } elsif ( scalar @dn_arr == 4 ) {
      $label = sprintf("%s (%s @ %s) branch of %s",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		       substr($dn_arr[1],3)
		      );
    } else {
      for ( $i = 1, $dn = ''; $i < scalar @dn_arr - 2; $i++ ) {
	$dn .= $dn_arr[$i];
      }
      $a = $dn =~ s/ou=/ -> /g;
      $label = sprintf("%s (%s @ %s) branch of %s",
		       $entry->get_value ('ou'),
		       $entry->get_value ('physicaldeliveryofficename'),
		       $entry->get_value ('l'),
		       $dn
		      );
    }

    push @orgs, {
		 value => $entry->dn,
		 label => $label
		};
  }
  return \@orgs;

  $ldap_crud->unbind;
}

# bl-1 ----------------------------------------------------------------------

has_field 'physicalDeliveryOfficeName' => (
					   label => 'physicalDeliveryOfficeName',
					   label_attr => { title => 'official office name as it is known to the world' },
					   wrapper_class => 'col-xs-4',
					   element_attr => { placeholder => 'Horns & Hooves LLC' },
					   required => 1,
					  );

has_field 'ou' => (
		   label => 'Org Unit',
		   label_attr => { title => 'top level name of the organization as it is used in physicalDeliveryOfficeName value of users' },
		   wrapper_class => 'col-xs-2',
		   element_attr => { placeholder => 'fo01' },
		   required => 1,
		  );

has_field 'businessCategory' => ( type => 'Select',
				  label => 'Business Category',
				  wrapper_class => 'col-xs-2',
				  options => [
					      { value => 'na', label => 'N/A',},
					      { value => 'it', label => 'IT',},
					      { value => 'trade', label => 'Trade',},
					      { value => 'telephony', label => 'Telephony',},
					      { value => 'fin', label => 'Financial',},
					      { value => 'tv', label => 'TV',},
					      { value => 'logistics', label => 'Logistics'},
					     ],
				);

has_field 'telephoneNumber' => (
				label => 'telephoneNumber',
				wrapper_class => 'col-xs-3',
				element_attr => { placeholder => '666' },
			       );

# bl-2 ----------------------------------------------------------------------

has_field 'postOfficeBox' => ( label => 'PB',
			    wrapper_class => 'col-xs-1',
			    element_attr => { placeholder => '121' },
			     );

has_field 'street' => ( label => 'Street',
			wrapper_class => 'col-xs-3',
			element_attr => { placeholder => 'Artema' },
		      );

has_field 'postalCode' => (
			   label => 'Postalcode',
			    wrapper_class => 'col-xs-2',
			    element_attr => { placeholder => '83100' },
			  );

has_field 'l' => (
		  label => 'Location',
		  label_attr => { title => 'location, commonly the city the office situated at' },
		  wrapper_class => 'col-xs-2',
		  element_attr => { placeholder => 'Donetsk' },
		  required => 1,
		 );

has_field 'st' => ( label => 'State',
		    label_attr => { title => 'state, commonly short form of the city' },
		    wrapper_class => 'col-xs-1',
		    element_attr => { placeholder => 'DN' },
		  );

# bl-3 ----------------------------------------------------------------------

has_field 'postalAddress' => ( label => 'PostalAdress',
			       wrapper_class => 'col-xs-3',
			       element_attr => { placeholder => '121, 4th floor' },
			     );

has_field 'registeredAddress' => ( label => 'Registered Adress',
				   wrapper_class => 'col-xs-3',
				   element_attr => { placeholder => '121, 4th floor' },
				 );

has_field 'description' => ( type => 'TextArea',
			     label => 'Description',
			     wrapper_class => 'col-xs-6',
			     element_attr => { placeholder => 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse sed dapibus nulla. Mauris vehicula vehicula ligula ac dapibus. Fusce vehicula a turpis sed. ' },
			     # cols => 30,
			     rows => 2
			   );

# bl-4 ----------------------------------------------------------------------


has_field 'aux_reset' => ( type => 'Reset',
			   wrapper_class => [ 'col-xs-2' ],
			   element_class => [ 'btn', 'btn-danger', 'btn-block', ],
			   element_wrapper_class => [ 'col-xs-12', ],
			   # value => 'Reset'
			 );

has_field 'aux_submit' => (
			   type => 'Submit',
			   wrapper_class => [ 'col-xs-10'],
			   element_class => [ 'btn', 'btn-success', 'btn-block', ],
			   # label_no_filter => 1,
			   # value => '<span class="glyphicon glyphicon-plus-sign"></span> Submit',
			   value => 'Submit'
			  );

# FIELDSETs -----------------------------------------------------------------

has_block 'bl-0' => ( tag => 'fieldset',
		      render_list => [ 'aux_parent' ],
		      label => '<abbr title="Head office" class="initialism"><span class="icon_building_alt" aria-hidden="true"></span></abbr>',
		      class => [ 'row', ]
		    );

has_block 'bl-1' => ( tag => 'fieldset',
		      render_list => [ 'physicalDeliveryOfficeName', 'ou', 'businessCategory', 'postOfficeBox', 'street' ],
		      label => '<abbr title="Geografical Address Related Data" class="initialism"><span class="icon_building" aria-hidden="true"></span></abbr>',
		      class => [ 'row', ]
		    );

has_block 'bl-2' => ( tag => 'fieldset',
		      render_list => [ 'l', 'st', 'postalCode', 'registeredAddress', 'postalAddress' ],
		      # label => '&nbsp;',
		      class => [ 'row', ]
		    );

has_block 'bl-3' => ( tag => 'fieldset',
		      render_list => [ 'telephoneNumber', 'description' ],
		      # label => '&nbsp;',
		      class => [ 'container-fluid', ]
		    );

has_block 'bl-4' => ( tag => 'fieldset',
		      render_list => [ 'aux_reset', 'aux_submit'],
		      # label => '&nbsp;',
		      class => [ 'row', ]
		    );

sub build_render_list {[
			'bl-0',
			'bl-1',
			'bl-2',
			'bl-3',
			'bl-4',
		       ]}

sub validate {
  my $self = shift;

  # if ( $self->field('password1')->value ne $self->field('password2')->value ) {
  #   $self->field('password2')->add_error('<span class="glyphicon glyphicon-exclamation-sign"></span>&nbsp;password and its confirmation does not match');
  # }

  # my $ldap_crud = $self->ldap_crud;
  # my $ldap = $ldap_crud->umi_bind({
  # 				   dn => 'uid=' . $self->uid . ',ou=people,dc=ibs',
  # 				   password => $self->pwd,
  # 				  });
  # my $mesg =
  #   $ldap_crud->umi_search( $ldap,
  # 			    {
  # 			     ldap_search_scope => 'sub',
  # 			     ldap_search_filter => '(&(givenname=' . 
  # 			     $self->field('fname')->value . ')(sn=' .
  # 			     $self->field('lname')->value . ')(uid=*-' .
  # 			     $self->field('login')->value . '))',
  # 			     ldap_search_base => 'ou=People,dc=ibs',
  # 			      ldap_search_attrs => [ 'uid' ],
  # 			    }
  # 			  );

  # if ($mesg->count) {
  #   my $err = '<span class="glyphicon glyphicon-exclamation-sign"></span> Fname+Lname+Login exists';
  #   $self->field('fname')->add_error($err);
  #   $self->field('lname')->add_error($err);
  #   $self->field('login')->add_error($err);

  #   $err = '<div class="alert alert-danger">' .
  #     '<span style="font-size: 140%" class="icon_error-oct" aria-hidden="true"></span>' .
  # 	'&nbsp;Account with the same fields &laquo;<strong>First Name&raquo;</strong>,' .
  # 	  ' &laquo;<strong>Last Name&raquo;</strong> and &laquo;<strong>Login&raquo;</strong>' .
  # 	    ' already exists!<br>Consider one of:<ul>' .
  # 	      '<li>change Login in case you need another account for the same person</li>' .
  # 		'<li>add service account to the existent one</li></ul></div>';
  #   my $error = $self->form->success_message;
  #   $self->form->error_message('');
  #   $self->form->add_form_error($error . $err);
  # }
  # $ldap->unbind;
}

sub update_model {
    use Data::Printer colored => 1, caller_info => 1;
    p(@_);

    my $self = shift;

    my $item = undef;
    if ( ! $self->item ) {
      warn '$$$$$$$$$$$$$$$$$$$$$$$$$$$$ add $$$$$$$$$$$$$$$$$$$$$$$$$$$$' . "\n";
      $self->add_form_error('<span class="fa fa-exclamation-circle">' .
			    '</span>&nbsp;first if');
      $item = $self->ldap_crud
	->obj_add(
		  {
		   'type' => 'org',
		   'params' => $self->{'params'},
		  }
		 );
    } elsif ( defined $self->{'item'}->{'act'} ) {
      $item = $self->item;
      warn '$$$$$$$$$$$$$$$$$$$$$$$$$$$$ modify $$$$$$$$$$$$$$$$$$$$$$$$$$$$' . "\n";
      # $self->add_form_error('middle elsif');
      # item => $c->model('LDAP_CRUD')
      # 	->obj_mod(
      # 		  {
      # 		   'type' => 'org',
      # 		   'params' => $params,
      # 		  }
      # 		 ),

    } else  {
      warn '$$$$$$$$$$$$$$$$$$$$$$$$$$$$ other $$$$$$$$$$$$$$$$$$$$$$$$$$$$' . "\n";

      $item = $self->item;
      $self->add_form_error('Final else');
    }

    return unless $item;

    $self->add_form_error( $item->{'message'} ) if $item->{'message'};

    # foreach my $field ( $self->all_fields ) {
    #     my $name = $field->name;
    #     next unless $item->can($name);
    #     $item->$name( $field->value );
    # }
}

######################################################################

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;
