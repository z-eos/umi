# -*- mode: cperl -*-
#

package UMI::Controller::Inventory;
use Moose;
use namespace::autoclean;
use Data::Printer;

BEGIN { extends 'Catalyst::Controller'; with 'Tools'; }

use UMI::Form::Inventory;
has 'form' => ( isa => 'UMI::Form::Inventory', is => 'rw',
		lazy => 1, default => sub { UMI::Form::Inventory->new },
		documentation => q{Complex Form to add new, nonexistent user account/s},
	      );


=head1 NAME

UMI::Controller::Inventory - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c, $ldapadduser_id ) = @_;
    my $params = $c->req->parameters;

    $self->form->add_inventory( defined $params->{add_inventory} ? $params->{add_inventory} : '' );
    my $final_message;

    # here we initialize repeatable fields to be rendered when the form is called from
    # another one
    if ( defined $self->form->add_inventory &&
	 $self->form->add_inventory ne '' &&
	 ! defined $params->{'compart.0.hwType'} ) {
      $params->{'compart.0.hwType'} = '' if ! $params->{'compart.0.hwType'};
    }

    $params->{'common_FileDMI'} = $c->req->upload('common_FileDMI') if $params->{'common_FileDMI'};
    $params->{'common_FileSMART'} = $c->req->upload('common_FileSMART') if $params->{'common_FileSMART'};

    $c->stash( template => 'inventory/inventory.tt',
	       form => $self->form,
	       final_message => $final_message, );
    return unless $self->form->process(
				       posted => ($c->req->method eq 'POST'),
				       params => $params,
				       ldap_crud => $c->model('LDAP_CRUD'),
				      );

    while ( my ($k, $v) = each %{$params} ) {
      delete $params->{$k} if $v eq '';
    }

    my $dmi = $self->create_inventory( $c->model('LDAP_CRUD'), $params );
    #$final_message->{success} = sprintf('<pre>%s</pre>', np($dmi->{success}, caller_info => 1, colored => 0)) if $dmi->{success};
    $final_message->{success} = $dmi->{success} if $dmi->{success};
    $final_message->{error} = $dmi->{error} if $dmi->{error};

    $c->stash( final_message => $final_message );

}

=head2 create_inventory

=cut

sub create_inventory {
  my  ( $self, $ldap_crud, $args ) = @_;

  $args->{common_hwAssignedTo} = 'unassigned'
    if defined $args->{common_hwAssignedTo} && $args->{common_hwAssignedTo} eq '';
  
  my ( $file_is, $return, $hw, $tmp, $k, $key, $v, $val, $i, $j, $l, $r, $compart, $add, $hwAssignedTo, $common_compart );


  if ( defined $args->{common_FileDMI}->{tempname} ) {
    $file_is = $self->file_is({ file => $args->{common_FileDMI}->{tempname} });
    return $return = { error => [ $file_is->{error} ] } if defined $file_is->{error};

    if ( $file_is->{success} eq 'dmidecode' ) {
      $hw = $self->file_dmi({ file => $args->{common_FileDMI}->{tempname}, });
      return $return = { error => $hw->{error} } if defined $hw->{error};
      return $return = { warning => $hw->{warning} } if defined $hw->{warning};
    }
  }

  # if ( $file_is->{success} eq 'lspci' ) {
  #   return $return = { error => $hw->{error} } if defined $hw->{error};
  #   return $return = { warning => $hw->{warning} } if defined $hw->{warning};
  # }

  # if ( $file_is->{success} eq 'pciconf' ) {
  #   return $return = { error => $hw->{error} } if defined $hw->{error};
  #   return $return = { warning => $hw->{warning} } if defined $hw->{warning};
  # }

  if ( defined $args->{common_FileSMART}->{tempname} ) {
    $file_is = $self->file_is({ file => $args->{common_FileSMART}->{tempname} });
    return $return = { error => [ $file_is->{error} ] } if defined $file_is->{error};

    if ( $file_is->{success} eq 'smartctl' ) {
      $tmp = $self->file_smart({ file => $args->{common_FileSMART}->{tempname}, });
      return $return = { error => $tmp->{error} } if defined $tmp->{error};
      return $return = { warning => $tmp->{warning} } if defined $tmp->{warning};
      $hw->{success}->{disk} = $tmp->{success}->{disk};
    }
  }

  $hwAssignedTo = '';
  # root object DN ( EXAMPLE: composite_srv )
  ($l, $r) = split(/_/, $args->{common_hwType});
  $l = ucfirst $l;
  # if ( $l ne 'Comparts' ) { # comparts has individual DNs
    $add->{root}->{dn} = sprintf('cn=%s-%s,ou=%s,%s',
				 $r,
				 $ldap_crud->last_seq({ base => 'ou=' . $l . ',' . $ldap_crud->{cfg}->{base}->{inventory},
							filter => '(cn=' . $r . '-*)',
							attr => 'cn' ,
							seq_pfx => $r . '-', }) + 1,
				 $l,
				 $ldap_crud->{cfg}->{base}->{inventory});

    push @{$add->{root}->{attrs}}, objectClass => $ldap_crud->{cfg}->{objectClass}->{inventory};
    $hwAssignedTo = $add->{root}->{dn};
  # }

  #--- Composite or Single Compart start ----------------------------------------------
  if ( $l eq 'Composite' || $l eq 'Comparts' || $l eq 'Singleboard' ) {
    if ( defined $hw->{success} ) { # initialized from files
      while ( ( $key, $val ) = each %{$hw->{success}} ) { # ->file_<dmi/lspci/pciconf/smartctl> value processing
	$i = 0; # number of comparts of each type (number of CPU,RAM, e.t.c.)
	# CN uniq index calculation
	$j = $ldap_crud->last_seq({ base => 'ou=Comparts,' . $ldap_crud->{cfg}->{base}->{inventory},
				    filter => '(cn=' . $key . '-*)',
				    attr => 'cn' ,
				    seq_pfx => $key . '-', }) + 1;
	foreach $compart ( @{$val} ) {
	  $add->{$key}->[$i]->{dn} = sprintf('cn=%s-%s,ou=Comparts,%s', $key, $j, $ldap_crud->{cfg}->{base}->{inventory});
	  push @{$add->{$key}->[$i]->{attrs}}, objectClass => $ldap_crud->{cfg}->{objectClass}->{inventory};
	  push @{$add->{$key}->[$i]->{attrs}}, hwState => $args->{common_hwState};
	  push @{$add->{$key}->[$i]->{attrs}}, hwStatus => 'assigned';
	  push @{$add->{$key}->[$i]->{attrs}}, hwType => 'comparts_' . $key;

	  if ( $hwAssignedTo ne '' ) {
	    push @{$add->{$key}->[$i]->{attrs}}, hwAssignedTo => $hwAssignedTo;
	  } elsif ( defined $args->{common_hwAssignedTo} && $args->{common_hwAssignedTo} ne '' ) {
	    push @{$add->{$key}->[$i]->{attrs}},
	      hwAssignedTo => $args->{common_hwAssignedTo} =~ /.*,$ldap_crud->{cfg}->{base}->{db}/ ?
	      $args->{common_hwAssignedTo} :
	      sprintf('%s=%s,%s',
		      $ldap_crud->{cfg}->{rdn}->{acc_root},
		      $args->{common_hwAssignedTo},
		      $ldap_crud->{cfg}->{base}->{acc_root});
	  }

	  push @{$add->{$key}->[$i]->{attrs}},
	    description => defined $args->{common_description} ? $args->{common_description} : 'stub description';

	  while (($k, $v) = each %{$compart}) {
	    push @{$add->{$key}->[$i]->{attrs}}, $k => $v if $v ne '';
	  }

	  $add->{$key}->[$i]->{ldif} = $ldap_crud->add( $add->{$key}->[$i]->{dn}, $add->{$key}->[$i]->{attrs} );
	  if ( $add->{$key}->[$i]->{ldif} ) {
	    push @{$return->{error}},
	      sprintf('Error during Compart inventory object creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s' .
		      $add->{$key}->[$i]->{ldif}->{html},
		      $add->{$key}->[$i]->{ldif}->{srv},
		      $add->{$key}->[$i]->{ldif}->{text});
	  } else {
	    push @{$return->{success}}, sprintf('%s<br >', $add->{$key}->[$i]->{dn}) ;
	  }

	  # comparts has individual DNs and here, we add them to the root obj
	  push @{$add->{root}->{attrs}}, 'hw' . $key => $add->{$key}->[$i]->{dn}
	    if $l ne 'Comparts';

	  $i++;
	  $j++;
	}
      }
    }
    #--- Repeatable field Compart start --- ( if any ) -----------------------
    undef $compart;
    foreach my $element ( $self->form->field('compart')->fields ) {
      foreach my $field ( $element->fields ) {
	next if $field->name eq 'remove' || ! defined $field->value;
	$tmp = $field->name ne 'hwMac' ? $field->value : $self->macnorm({ mac => $field->value });
	push @{$compart->{ldif}->{attrs}}, $field->name => $tmp;
	$compart->{ldif}->{hash}->{$field->name} = $tmp;
      }
      next if ! defined $compart->{ldif}->{hash}->{hwType};
      push @{$compart->{ldif}->{attrs}}, objectClass => $ldap_crud->{cfg}->{objectClass}->{inventory};
      push @{$compart->{ldif}->{attrs}}, hwStatus => 'assigned';
      if ( $hwAssignedTo ne '' ) {
	push @{$compart->{ldif}->{attrs}}, hwAssignedTo => $hwAssignedTo;
      } elsif ( defined $args->{common_hwAssignedTo} && $args->{common_hwAssignedTo} ne '' ) {
	push @{$compart->{ldif}->{attrs}},
	  hwAssignedTo => $args->{common_hwAssignedTo} =~ /.*,$ldap_crud->{cfg}->{base}->{db}/ ?
	  $args->{common_hwAssignedTo} :
	  sprintf('uid=%s,ou=People,%s',
		  $args->{common_hwAssignedTo},
		  $ldap_crud->{cfg}->{base}->{db});
      }

      $compart->{type} = (split(/_/, $compart->{ldif}->{hash}->{hwType}))[1];
      $j = $ldap_crud->last_seq({ base => 'ou=Comparts,' . $ldap_crud->{cfg}->{base}->{inventory},
				  filter => '(cn=' . $compart->{type} . '-*)',
				  attr => 'cn' ,
				  seq_pfx => $compart->{type} . '-', }) + 1;
      $compart->{ldif}->{dn} = sprintf('cn=%s-%s,ou=Comparts,%s', $compart->{type}, $j, $ldap_crud->{cfg}->{base}->{inventory});
      $compart->{ldif}->{mesg} = $ldap_crud->add( $compart->{ldif}->{dn}, $compart->{ldif}->{attrs} );
      if ( $compart->{ldif}->{mesg} ) {
	push @{$return->{error}},
	  sprintf('Error during Compart (repeatable) inventory object creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s' .
		  $compart->{ldif}->{mesg}->{html},
		  $compart->{ldif}->{mesg}->{srv},
		  $compart->{ldif}->{mesg}->{text});
      } else {
	push @{$return->{success}}, sprintf('%s<br >', $compart->{ldif}->{dn}) ;
      }
      push @{$add->{root}->{attrs}}, 'hw' . ucfirst $compart->{type} => $compart->{ldif}->{dn};
      push @{$add->{repeatable}}, $compart;
      delete $compart->{ldif};
    }
    #--- Repeatable field Compart stop ----------------------------------------
    
    #--- Composite or Single Compart stop -----------------------------------------------
  }

  $common_compart = '';
  # rest of the root obj attributes (form `common_*' fields data)
  while ( ( $key, $val ) = each %{$args} ) {
    # p $key; p $val;
    next if $key !~ /common_.*/ || $key =~ /common_File.*/;
    ( $l, $r) = split(/_/, $key);
    $tmp = $r ne 'hwMac' ? $val : $self->macnorm({ mac => $val });
    
    if ( $r eq 'hwAssignedTo' ) {
      if ( $val eq '' ) {
	$tmp = 'unassigned';
      } elsif ( $val !~ /.*,$ldap_crud->{cfg}->{base}->{db}/ ) {
	$tmp = sprintf('%s=%s,%s',
		       $ldap_crud->{cfg}->{rdn}->{acc_root},
		       $val,
		       $ldap_crud->{cfg}->{base}->{acc_root});
      } else {
	$tmp = $val;
      }
    }

    push @{$add->{root}->{attrs}}, $r => $tmp;

    $common_compart = 'hw' . substr($val,9) if $r eq 'hwType' && $val =~ /comparts_.*/;

  }

  # add DN of common_compart object to the composite (root) object if defined
  if ( $common_compart && $args->{common_hwAssignedTo} ) {
    $tmp = $ldap_crud->modify( $args->{common_hwAssignedTo},
			       [ 'add' => [ $common_compart => $add->{root}->{dn}] ] );
    push @{$return->{error}}, $tmp if $tmp;
  }

  $add->{root}->{ldif} = $ldap_crud->add( $add->{root}->{dn}, $add->{root}->{attrs} );
  if ( $add->{root}->{ldif} ) {
    push @{$return->{error}},
      sprintf('Error during Composite inventory object %s creation occured: %s<br><b>srv: </b><pre>%s</pre><b>text: </b>%s' .
	      $add->{root}->{dn},
	      $add->{root}->{ldif}->{html},
	      $add->{root}->{ldif}->{srv},
	      $add->{root}->{ldif}->{text});
  } else {
    push @{$return->{success}}, sprintf('%s<br >', $add->{root}->{dn}) ;
  }
  
  p $add; # p $return->{warning} = $add;
  return $return; # = { success => $add };
}


=head1 AUTHOR

Zeus

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
