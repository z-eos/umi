package UMI::Model::LDAP_CRUD;

use base 'Catalyst::Model::Factory::PerRequest';

__PACKAGE__->config(
	class => 'LDAP_CRUD',
	# $args for new can be hard-coded here
	# or set dynamically in prepare_arguments
# 	args  => {
# 		uid => '',
# 		pwd => '',
# 	},
);

sub prepare_arguments {
	my ($self, $c) = @_; 
	my $args = $self->next::method($c, {});
	return {
		%{$args},
		uid => $c->session->{umi_ldap_uid},
		pwd => $c->session->{umi_ldap_password},
	};
}

1;
