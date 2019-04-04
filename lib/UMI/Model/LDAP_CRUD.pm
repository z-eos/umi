#-*- cperl -*-
#

package UMI::Model::LDAP_CRUD;

use Data::Printer { use_prototypes => 0, caller_info => 1 };

use base 'Catalyst::Model::Factory::PerRequest';

__PACKAGE__->config(
		    class => 'LDAP_CRUD',
		    # $args for new, can be hard-coded here or set dynamically in prepare_arguments
		    # args  => {
		    # 	      uid => '',
		    # 	      pwd => '',
		    # 	     },
		   );

sub prepare_arguments {
  my ($self, $c) = @_; 
  my $args = $self->next::method($c, {});

  if ( ! defined $c->session->{auth_uid} || ! defined $c->session->{auth_pwd} ) {
    p $args;
    p $c->session->{auth_uid};
    p $c->session->{auth_pwd};
  }

  return {
	  %{$args},
	  uid  => $c->session->{auth_uid},
	  pwd  => $c->session->{auth_pwd},
	  user => $c->user,
	  role_admin => $c->check_user_roles( qw/admin/ ),
	  # path_to_images => $c->path_to('root', 'static', 'images'),
	 };
}

1;
