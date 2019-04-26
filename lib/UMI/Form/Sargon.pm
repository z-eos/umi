# -*- mode: cperl -*-
#

package UMI::Form::Sargon;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP';
	with 'Tools', 'HTML::FormHandler::Render::RepeatableJs'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable' );

has '+enctype' => ( default => 'multipart/form-data');
has '+action'  => ( default => '/sargon' );

sub build_form_element_class { [ qw(formajaxer) ] }

sub build_update_subfields {
  by_flag => { repeatable => { do_wrapper => 1, do_label => 1 } }
}

sub html_attributes {
  my ( $self, $field, $type, $attr ) = @_;
  push @{$attr->{class}}, 'required'
    if ( $type eq 'label' && $field->required );

  $attr->{class} = ['hfh', 'repinst']
    if $type eq 'wrapper' && $field->has_flag('is_contains');

  return $attr;
}

has_field 'aux_dn_form_to_modify' => ( type => 'Hidden', );

# https://github.com/graygnuorg/sargon

# sargonUser                 multiselect of uid and/or %gid (for anonymous access, user is ANONYMOUS)
# sargonHost                 multiselect of grayHostName from ou=machines,dc=umidb
# sargonAllow                select of "endppoints" https://github.com/graygnuorg/sargon/blob/master/server/action.go
# sargonDeny                 select of "endppoints"
# sargonOrder                single decimal num (optional)
# sargonMount                input text (multiple, begin with /)
# sargonAllowCapability      select CAPABILITIES(7) beginning or not with CAP_ (`!' is negation)

# sargonAllowPrivileged      bool single
# sargonMaxMemory            input text - number
# sargonMaxKernelMemory      input text - number


has_field 'cn'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'CN',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-3', ],
       element_attr          => { placeholder => 'Common Name.',
				  title       => 'Common Name.'},
       wrapper_class         => [ 'row', ],
       required              => 1
     );

has_field 'uid'
  => ( type                  => 'Multiple',
       label                 => 'Users',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-user',
				  'data-ico-r'       => 'fa-user',
				  'data-placeholder' => 'users', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&uids,
       # required              => 1,
     );

has_field 'groups'
  => ( type                  => 'Multiple',
       label                 => 'Groups',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-users',
				  'data-ico-r'       => 'fa-users',
				  'data-placeholder' => 'groups', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&groups,
       # required              => 1,
     );

has_field 'netgroups'
  => ( type                  => 'Multiple',
       label                 => 'NetGroups',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-user-friends',
				  'data-ico-r'       => 'fa-user-friends',
				  'data-placeholder' => 'netgroups', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&netgroup,
       # required              => 1,
     );

has_field 'host'
  => ( type                  => 'Multiple',
       label                 => 'Hosts',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-desktop',
				  'data-ico-r'       => 'fa-desktop',
				  'data-placeholder' => 'hosts', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&hosts,
       # required              => 1,
     );

has_field 'allow'
  => ( type                  => 'Multiple',
       label                 => 'Allow',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-shield-alt',
				  'data-ico-r'       => 'fa-shield-alt',
				  'data-placeholder' => 'allowed actions', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&endpoints,
       # required              => 1,
     );

has_field 'deny'
  => ( type                  => 'Multiple',
       label                 => 'Deny',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-shield-alt',
				  'data-ico-r'       => 'fa-shield-alt',
				  'data-placeholder' => 'denied actions', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&endpoints,
       # required              => 1,
     );

has_field 'capab'
  => ( type                  => 'Multiple',
       label                 => 'Cpabilities',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_attr          => { 'data-ico-l'       => 'fa-box-open',
				  'data-ico-r'       => 'fa-box-open',
				  'data-placeholder' => 'capabilities', },
       element_wrapper_class => [ 'input-sm', 'col-10' ],
       element_class         => [ 'umi-multiselect' ],
       wrapper_class         => [ 'row', ],
       options_method        => \&capab,
       # required              => 1,
     );

has_field 'order'
  => ( # apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'Order',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-3', ],
       element_attr          => { placeholder => 'An integer to order sargonACL entries. If not present, 0 is assumed.',
				  title => 'An integer to order sargonACL entries. If not present, 0 is assumed.'},
       wrapper_class         => [ 'row', ],
       #       required              => 1
     );

has_field 'aux_delim_mount'
  => ( type => 'Display',
       html => '<div class="form-group row"><label class="col-2 text-right font-weight-bold">Mount</label></div>',
     );

has_field 'aux_add_mount'
  => ( type          => 'AddElement',
       repeatable    => 'mount',
       value         => 'Add new Mount',
       element_class => [ 'btn-success', ],
       element_wrapper_class => [ 'col-3', 'px-0', ],
       wrapper_class => [ 'row', 'offset-md-2', ],
     );

has_field 'mount'
  => ( type                  => 'Repeatable',
       setup_for_js          => 1,
       do_wrapper            => 1,
       label                 => 'Mount',
       element_wrapper_class => [ 'controls', ],
       element_class         => [ 'row', 'offset-md-2', 'col-10', 'p-0', ],
     );

has_field 'mount.mount'
  => ( # apply                 => [ NoSpaces, NotAllDigits, Printable ],
       do_label              => 0,
       element_attr          => { placeholder => 'Name of the directory on the host filesystem, which is allowed for bind and mount operations.',
				  title => 'Name of the directory on the host filesystem, which is allowed for bind and mount operations.'},
       wrapper_class         => [ 'col-8', 'px-0', ],
       #       required              => 1
     );

has_field 'mount.remove'
  => ( type => 'RmElement',
       value => 'Remove this Mount',
       element_class => [ 'btn-danger', ],
       wrapper_class => [ 'col-4', 'pr-0', ],
     );

has_field 'priv'
  => ( type                  => 'Checkbox',
       label                 => 'privileged',
       element_attr          => { title => 'allowed to create privileged containers' },
       element_class         => [ 'form-check-input' ],
       wrapper_class         => [ 'form-check', 'offset-md-2' ],
     );

has_field 'maxmem'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'MaxMem',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => 'Limit on memory usage. The value is an integer optionally suffixed with K, M, or G (case-insensitive).',
				  title => 'Limit on memory usage. The value is an integer optionally suffixed with K, M, or G (case-insensitive).'},
       wrapper_class         => [ 'row', ],
       #       required              => 1
     );

has_field 'maxkernmem'
  => ( apply                 => [ NoSpaces, NotAllDigits, Printable ],
       label                 => 'MaxKernMem',
       label_class           => [ 'col-2', 'text-right', 'font-weight-bold', ],
       element_wrapper_class => [ 'input-sm', 'col-10', ],
       element_attr          => { placeholder => 'Limit on kernel memory usage. The value is an integer optionally suffixed with K, M, or G (case-insensitive).',
				title => 'Limit on kernel memory usage. The value is an integer optionally suffixed with K, M, or G (case-insensitive).'},
       wrapper_class         => [ 'row', ],
       #       required              => 1
     );

has_field 'aux_reset'
  => ( type          => 'Reset',
       element_class => [ qw( btn
			      btn-danger
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ 'col-4' ],
       value         => 'Reset' );

has_field 'aux_submit'
  => ( type          => 'Submit',
       element_class => [ qw( btn
			      btn-success
			      btn-block
			      font-weight-bold
			      text-uppercase) ],
       wrapper_class => [ 'col-8', ],
       value         => 'Submit' );

has_block 'aux_submitit'
  => ( tag => 'div',
       render_list => [ 'aux_reset', 'aux_submit'],
       class => [ 'row', 'mt-5', ]
     );


# sub build_render_list {[ qw( aux_dn_form_to_modify
# 			     uid
# 			     groups
# 			     host
# 			     aux_add_allow
# 			     allow
# 			     deny
# 			     order
# 			     aux_add_mount
# 			     mount
# 			     capab
# 			     maxmem
# 			     maxkernmem
# 			     priv
# 			     aux_submitit ) ]}

# sub validate {
#   my $self = shift;
#   my $ldap_crud = $self->ldap_crud;
#   my $mesg = $ldap_crud->search({
# 				 scope => 'one',
# 				 filter => '(cn=' .
# 				 $self->utf2lat( $self->field('cn')->value ) . ')',
# 				 base => $ldap_crud->cfg->{base}->{netgroup},
# 				 attrs => [ 'cn' ],
# 				});
#   $self->field('cn')->add_error('NisNetgroup with name <em>&laquo;' .
#   				$self->utf2lat( $self->field('cn')->value ) . '&raquo;</em> already exists.')
#     if ($mesg->count);
# }

######################################################################

sub uids {
  my $self = shift;
  return unless $self->form->ldap_crud;
  my $uids = $self->form->ldap_crud->
    bld_select({ base   => $self->form->ldap_crud->cfg->{base}->{acc_root},
		 filter => '(&(objectClass=authorizedServiceObject)(authorizedService=ssh*)(uid=*))',
		 scope  => 'sub',
		 attr   => [ 'uid', ],});
  unshift @{$uids},
    { label => 'ANONYMOUS', value => 'ANONYMOUS' },
    { label => 'ALL', value => 'ALL' };

  return $uids;
}

sub groups {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_group;
}

sub netgroup {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->
    bld_select({ base   => 'ou=category,' . $self->form->ldap_crud->cfg->{base}->{netgroup},
		 filter => '(cn=*)',
		 scope  => 'one',
		 attr   => [ 'cn', 'description', ],});
}

sub hosts {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->
    bld_select({ base   => $self->form->ldap_crud->cfg->{base}->{machines},
		 filter => '(cn=*)',
		 attr   => [ 'grayHostName', ],});
}

sub endpoints {
  return (
	  'ALL'                         => 'ALL',
	  'BuildPrune',			=> 'BuildPrune --- Delete builder cache.',
	  'ConfigCreate',		=> 'ConfigCreate --- Create a config.',
	  'ConfigDelete',		=> 'ConfigDelete --- Delete a config.',
	  'ConfigInspect',		=> 'ConfigInspect --- Inspect a config.',
	  'ConfigList',			=> 'ConfigList --- List configs.',
	  'ConfigUpdate',		=> 'ConfigUpdate --- Update a config.',
	  'ContainerArchive',		=> 'ContainerArchive --- Get an archive of a filesystem resource in a container.',
	  'ContainerArchiveInfo',	=> 'ContainerArchiveInfo --- Get information about files in a container.',
	  'ContainerAttach',		=> 'ContainerAttach --- Attach to a container.',
	  'ContainerAttachWebsocket',	=> 'ContainerAttachWebsocket --- Attach to a container via a websocket.',
	  'ContainerChanges',		=> 'ContainerChanges --- Get changes on a container’s filesystem.',
	  'ContainerCreate',		=> 'ContainerCreate --- Create a container.',
	  'ContainerDelete',		=> 'ContainerDelete --- Remove a container.',
	  'ContainerExec',		=> 'ContainerExec --- Create an exec instance.',
	  'ContainerExport',		=> 'ContainerExport --- Export a container.',
	  'ContainerInspect',		=> 'ContainerInspect --- Inspect a container.',
	  'ContainerKill',		=> 'ContainerKill --- Kill a container.',
	  'ContainerList',		=> 'ContainerList --- List containers.',
	  'ContainerLogs',		=> 'ContainerLogs --- Get container logs.',
	  'ContainerPause',		=> 'ContainerPause --- Pause a container.',
	  'ContainerPrune',		=> 'ContainerPrune --- Delete stopped containers.',
	  'ContainerRename',		=> 'ContainerRename --- Rename a container.',
	  'ContainerResize',		=> 'ContainerResize --- Resize a container TTY.',
	  'ContainerRestart',		=> 'ContainerRestart --- Restart a container.',
	  'ContainerStart',		=> 'ContainerStart --- Start a container.',
	  'ContainerStats',		=> 'ContainerStats --- Get container stats based on resource usage.',
	  'ContainerStop',		=> 'ContainerStop --- Stop a container.',
	  'ContainerTop',		=> 'ContainerTop --- List processes running inside a container.',
	  'ContainerUnpause',		=> 'ContainerUnpause --- Unpause a container.',
	  'ContainerUpdate',		=> 'ContainerUpdate --- Update a container.',
	  'ContainerWait',		=> 'ContainerWait --- Wait for a container.',
	  'DistributionInspect',	=> 'DistributionInspect --- Get image information from the registry.',
	  'ExecInspect',		=> 'ExecInspect --- Inspect an exec instance.',
	  'ExecResize',			=> 'ExecResize --- Resize an exec instance.',
	  'ExecStart',			=> 'ExecStart --- Start an exec instance.',
	  'GetPluginPrivileges',	=> 'GetPluginPrivileges --- Get plugin privileges.',
	  'ImageBuild',			=> 'ImageBuild --- Build an image.',
	  'ImageCommit',		=> 'ImageCommit --- Create a new image from a container.',
	  'ImageCreate',		=> 'ImageCreate --- Create an image.',
	  'ImageDelete',		=> 'ImageDelete --- Remove an image.',
	  'ImageGet',			=> 'ImageGet --- Export an image.',
	  'ImageGetAll',		=> 'ImageGetAll --- Export several images.',
	  'ImageHistory',		=> 'ImageHistory --- Get the history of an image.',
	  'ImageInspect',		=> 'ImageInspect --- Inspect an image.',
	  'ImageList',			=> 'ImageList --- List Images.',
	  'ImageLoad',			=> 'ImageLoad --- Import images.',
	  'ImagePrune',			=> 'ImagePrune --- Delete unused images.',
	  'ImagePush',			=> 'ImagePush --- Push an image.',
	  'ImageSearch',		=> 'ImageSearch --- Search images.',
	  'ImageTag',			=> 'ImageTag --- Tag an image.',
	  'NetworkConnect',		=> 'NetworkConnect --- Connect a container to a network.',
	  'NetworkCreate',		=> 'NetworkCreate --- Create a network.',
	  'NetworkDelete',		=> 'NetworkDelete --- Remove a network.',
	  'NetworkDisconnect',		=> 'NetworkDisconnect --- Disconnect a container from a network.',
	  'NetworkInspect',		=> 'NetworkInspect --- Inspect a network.',
	  'NetworkList',		=> 'NetworkList --- List networks.',
	  'NetworkPrune',		=> 'NetworkPrune --- Delete unused networks.',
	  'NodeDelete',			=> 'NodeDelete --- Delete a node.',
	  'NodeInspect',		=> 'NodeInspect --- Inspect a node.',
	  'NodeList',			=> 'NodeList --- List nodes.',
	  'NodeUpdate',			=> 'NodeUpdate --- Update a node.',
	  'PluginCreate',		=> 'PluginCreate --- Create a plugin.',
	  'PluginDelete',		=> 'PluginDelete --- Remove a plugin.',
	  'PluginDisable',		=> 'PluginDisable --- Disable a plugin.',
	  'PluginEnable',		=> 'PluginEnable --- Enable a plugin.',
	  'PluginInspect',		=> 'PluginInspect --- Inspect a plugin.',
	  'PluginList',			=> 'PluginList --- List plugins.',
	  'PluginPull',			=> 'PluginPull --- Install a plugin.',
	  'PluginPush',			=> 'PluginPush --- Push a plugin.',
	  'PluginSet',			=> 'PluginSet --- Configure a plugin.',
	  'PluginUpgrade',		=> 'PluginUpgrade --- Upgrade a plugin.',
	  'PutContainerArchive',	=> 'PutContainerArchive --- Extract an archive of files or folders to a directory in a container.',
	  'SecretCreate',		=> 'SecretCreate --- Create a secret.',
	  'SecretDelete',		=> 'SecretDelete --- Delete a secret.',
	  'SecretInspect',		=> 'SecretInspect --- Inspect a secret.',
	  'SecretList',			=> 'SecretList --- List secrets.',
	  'SecretUpdate',		=> 'SecretUpdate --- Update a Secret.',
	  'ServiceCreate',		=> 'ServiceCreate --- Create a service.',
	  'ServiceDelete',		=> 'ServiceDelete --- Delete a service.',
	  'ServiceInspect',		=> 'ServiceInspect --- Inspect a service.',
	  'ServiceList',		=> 'ServiceList --- List services.',
	  'ServiceLogs',		=> 'ServiceLogs --- Get service logs.',
	  'ServiceUpdate',		=> 'ServiceUpdate --- Update a service.',
	  'Session',			=> 'Session --- Initialize interactive session.',
	  'SwarmInit',			=> 'SwarmInit --- Initialize a new swarm.',
	  'SwarmInspect',		=> 'SwarmInspect --- Inspect swarm.',
	  'SwarmJoin',			=> 'SwarmJoin --- Join an existing swarm.',
	  'SwarmLeave',			=> 'SwarmLeave --- Leave a swarm.',
	  'SwarmUnlock',		=> 'SwarmUnlock --- Unlock a locked manager.',
	  'SwarmUnlockkey',		=> 'SwarmUnlockkey --- Get the unlock key.',
	  'SwarmUpdate',		=> 'SwarmUpdate --- Update a swarm.',
	  'SystemAuth',			=> 'SystemAuth --- Check auth configuration.',
	  'SystemDataUsage',		=> 'SystemDataUsage --- Get data usage information.',
	  'SystemEvents',		=> 'SystemEvents --- Monitor events.',
	  'SystemInfo',			=> 'SystemInfo --- Get system information.',
	  'SystemPing',			=> 'SystemPing --- Ping.',
	  'SystemVersion',		=> 'SystemVersion --- Get version.',
	  'TaskInspect',		=> 'TaskInspect --- Inspect a task.',
	  'TaskList',			=> 'TaskList --- List tasks.',
	  'TaskLogs',			=> 'TaskLogs --- Get task logs.',
	  'VolumeCreate',		=> 'VolumeCreate --- Create a volume.',
	  'VolumeDelete',		=> 'VolumeDelete --- Remove a volume.',
	  'VolumeInspect',		=> 'VolumeInspect --- Inspect a volume.',
	  'VolumeList',			=> 'VolumeList --- List volumes.',
	  'VolumePrune',		=> 'VolumePrune --- Delete unused volumes.',
	 );
}

sub capab {
  return (
	  'CAP_AUDIT_CONTROL' => 'CAP_AUDIT_CONTROL',
	  'CAP_AUDIT_READ' => 'CAP_AUDIT_READ',
	  'CAP_AUDIT_WRITE' => 'CAP_AUDIT_WRITE',
	  'CAP_BLOCK_SUSPEND' => 'CAP_BLOCK_SUSPEND',
	  'CAP_CHOWN' => 'CAP_CHOWN',
	  'CAP_DAC_OVERRIDE' => 'CAP_DAC_OVERRIDE',
	  'CAP_DAC_READ_SEARCH' => 'CAP_DAC_READ_SEARCH',
	  'CAP_FOWNER' => 'CAP_FOWNER',
	  'CAP_FSETID' => 'CAP_FSETID',
	  'CAP_IPC_LOCK' => 'CAP_IPC_LOCK',
	  'CAP_IPC_OWNER' => 'CAP_IPC_OWNER',
	  'CAP_KILL' => 'CAP_KILL',
	  'CAP_LEASE' => 'CAP_LEASE',
	  'CAP_LINUX_IMMUTABLE' => 'CAP_LINUX_IMMUTABLE',
	  'CAP_MAC_ADMIN' => 'CAP_MAC_ADMIN',
	  'CAP_MAC_OVERRIDE' => 'CAP_MAC_OVERRIDE',
	  'CAP_MKNOD' => 'CAP_MKNOD',
	  'CAP_NET_ADMIN' => 'CAP_NET_ADMIN',
	  'CAP_NET_BIND_SERVICE' => 'CAP_NET_BIND_SERVICE',
	  'CAP_NET_BROADCAST' => 'CAP_NET_BROADCAST',
	  'CAP_NET_RAW' => 'CAP_NET_RAW',
	  'CAP_SETGID' => 'CAP_SETGID ',
	  'CAP_SETFCAP' => 'CAP_SETFCAP',
	  'CAP_SETPCAP' => 'CAP_SETPCAP',
	  'CAP_SETUID' => 'CAP_SETUID',
	  'CAP_SYS_ADMIN' => 'CAP_SYS_ADMIN',
	  'CAP_SYS_BOOT' => 'CAP_SYS_BOOT',
	  'CAP_SYS_CHROOT' => 'CAP_SYS_CHROOT',
	  'CAP_SYS_MODULE' => 'CAP_SYS_MODULE',
	  'CAP_SYS_NICE' => 'CAP_SYS_NICE',
	  'CAP_SYS_PACCT' => 'CAP_SYS_PACCT',
	  'CAP_SYS_PTRACE' => 'CAP_SYS_PTRACE',
	  'CAP_SYS_RAWIO' => 'CAP_SYS_RAWIO',
	  'CAP_SYS_RESOURCE' => 'CAP_SYS_RESOURCE',
	  'CAP_SYS_TIME' => 'CAP_SYS_TIME',
	  'CAP_SYS_TTY_CONFIG' => 'CAP_SYS_TTY_CONFIG',
	  'CAP_SYSLOG' => 'CAP_SYSLOG',
	  'CAP_WAKE_ALARM' => 'CAP_WAKE_ALARM',
	 );
}

no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;
