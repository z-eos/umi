# -*- mode: cperl -*-
#

package UMI::Form::Inventory;

use HTML::FormHandler::Moose;
BEGIN { extends 'UMI::Form::LDAP';
	with 'Tools', 'HTML::FormHandler::Render::RepeatableJs'; }

use HTML::FormHandler::Types ('NoSpaces', 'WordChars', 'NotAllDigits', 'Printable', 'StrongPassword' );

# has '+error_message' => ( default => 'There were errors in your form.' );has '+item_class' => ( default =>'Inventory' );
has '+enctype' => ( default => 'multipart/form-data');
has 'add_inventory' => ( is => 'rw', ); # set if we add inventory rather than create a new one

sub build_form_element_class { [ 'form-horizontal', 'tab-content' ] }

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

has_field 'add_inventory' => ( type => 'Hidden', );

######################################################################
#== COMMON DATA ====================================================
######################################################################

# --- common fields header start ---------------------------------------------

has_field 'common_hwType'
  => ( type => 'Select',
       label => 'Object Type', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { 'data-name' => 'common_hwtype',
			 'data-group' => 'common', },
       empty_select => '--- Choose an Object Type ---',
       options
       => [
	   { value => 'composite_srv',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => 'composite_srv', },
	     label => 'composite: Server' },
	   { value => 'composite_ws',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => 'composite_ws', },
	     label => 'composite: Work Station' },

	   
	   { value => 'comparts_cpu',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => 'comparts_cpu', },
	     label => 'compart: CPU' },
	   { value => 'comparts_if',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => 'comparts_if', },
	     label => 'compart: IF (ether, bt, wlan)' },
	   { value => 'comparts_mb' ,
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => 'comparts_mb' , },
	     label => 'compart: Mother Board' },
	   { value => 'comparts_ram',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => 'comparts_ram', },
	     label => 'compart: RAM' },
	   { value => 'comparts_disk',
	     attributes => {'data-relation-prefix' => 'common_',
			    'data-relation' => 'comparts_disk', },
	     label => 'compart: DISK (HDD/SSD)' },

	   
	   { value => 'consumable_hs',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'consumable: HeadSet' },
	   { value => 'consumable_kbd',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'consumable: Keyboard' },
	   { value => 'consumable_ms',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'consumable: Mouse' },
	   { value => 'consumable_ms',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'consumable: Lead Power Extender (LPE)' },

	   
	   { value => 'singleboard_ap',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: Access Point', },
	   { value => 'singleboard_com',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: Commutator', },
	   { value => 'singleboard_mfu',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: MFU', },
	   { value => 'singleboard_monitor',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: Monitor', },
	   { value => 'singleboard_prn',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: Printer', },
	   { value => 'singleboard_ups',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: Uninterruptable Power Supply (UPS)', },
	   { value => 'singleboard_wrt',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'singleboard: Router (WRT)', },

	   
	   { value => 'furniture_chr',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'furniture: Chair' },
	   { value => 'furniture_tbl',
	     attributes => { 'data-relation-prefix' => 'common_',
			     'data-relation' => '', },
	     label => 'furniture: Table' },
	  ],
       required => 1 );

has_field 'common_FileDMI'
  => ( type => 'Upload',
       label => 'DMI', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_composite_srv', 'common_composite_ws', 'common_comparts_mb', 'common_comparts_cpu', 'common_comparts_ram', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
       element_attr => { title => 'default output of dmidecode(8)', },
       # max_size => '50000'
     );

has_field 'common_FileSMART'
  => ( type => 'Upload',
       label => 'S.M.A.R.T.', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_composite_srv', 'common_composite_ws', 'common_comparts_disk', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
       element_attr => { title => 'output of smartctl(8) with option -i', },
       # max_size => '50000'
     );

has_field 'common_hwAssignedTo'
  => ( apply => [ Printable ],
       label => 'Assigned To', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'UID or DN, like &laquo;taf.taf2&raquo; or &laquo;uid=taf.taf2,ou=People,dc=umidb&raquo;',
		       title => 'UID or DN for person as assignee, DN for hwInventory object as assignee', },
     );

has_field 'common_hwStatus'
  => ( type => 'Select',
       label => 'Status', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Initial state of the object',
			 'autocomplete' => 'off',
			 'data-name' => 'state',
			 'data-group' => 'composite', },
       options => [{ value => '', label => '--- Choose Status ---'},
		   { value => 'assigned', label => 'Assigned'},
		   { value => 'unassigned', label => 'Unassigned'},
		   { value => 'stolen', label => 'Stolen'},
		   { value => 'lost', label => 'Lost'}, ],
       required => 1 );

has_field 'common_hwState'
  => ( type => 'Select',
       label => 'State', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Initial state of the object',
			 'autocomplete' => 'off',
			 'data-name' => 'state',
			 'data-group' => 'singleboard', },
       options => [{ value => '', label => '--- Choose State ---'},
		   { value => 'new', label => 'New'},
		   { value => 'good', label => 'Good'},
		   { value => 'bad', label => 'Bad'},
		   { value => 'broken', label => 'Broken'},
		   { value => 'burned', label => 'Burned'},
		   { value => 'gleetches', label => 'Gleetches'},],
       required => 1 );

# --- common fields header end -----------------------------------------------

has_field 'common_inventoryNumber'
  => ( apply => [ Printable ],
       label => 'Inventory Number', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '533', },
     );

has_field 'common_description'
  => ( type => 'TextArea',
       label => 'Description', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Any description.',
			 'autocomplete' => 'off', },
       cols => 30, rows => 1);

has_field 'common_hwManufacturer'
  => ( apply => [ Printable ],
       label => 'Manufacturer', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Mikrotik', },
     );

has_field 'common_hwModel'
  => ( apply => [ Printable ],
       label => 'Model', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'RouterBOARD cAP 2n', },
     );

has_field 'common_hwSerialNumber'
  => ( apply => [ Printable ],
       label => 'Serial Number', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '654705AABCD3/533', },
     );

#!!---
has_field 'common_hwFamily'
  => ( apply => [ Printable ],
       label => 'Family', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', 'common_comparts_cpu',  'common_comparts_if', 'common_comparts_ram', 'common_comparts_disk', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'like CPU family' },
     );

has_field 'common_hwFccId'
  => ( apply => [ Printable ],
       label => 'FCC ID', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', 'common_comparts_cpu',  'common_comparts_if', 'common_comparts_ram', 'common_comparts_disk', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'TV7RBCM2N',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwFirmware'
  => ( apply => [ Printable ],
       label => 'Firmware', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', 'common_comparts_cpu',  'common_comparts_if', 'common_comparts_ram', 'common_comparts_disk', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '3.22',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwFirmwareType'
  => ( apply => [ Printable ],
       label => 'Firmware Type', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', 'common_comparts_cpu',  'common_comparts_if', 'common_comparts_ram', 'common_comparts_disk', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'ar9330L',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSizeRam'
  => ( apply => [ Printable ],
       label => 'RAM Size', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'comparts_ram', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '64.0MiB',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSpeed'
  => ( apply => [ Printable ],
       label => 'Speed', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '400MHz',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwProductName'
  => ( apply => [ Printable ],
       label => 'Product Name', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '880GMA-E45 (MS-7623)',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwBios'
  => ( apply => [ Printable ],
       label => 'BIOS', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'some BIOS info',
			 'data-name' => 'ap',
			 'data-group' => 'common', },
     );

has_field 'common_hwBiosVendor'
  => ( label => 'BIOS Vendor', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'American Megatrends Inc.',
			 'data-name' => 'ap',
			 'data-group' => 'common', },
     );

has_field 'common_hwBiosVersion'
  => ( apply => [ Printable ],
       label => 'BIOS Version', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'V17.5',
			 'data-name' => 'ap',
			 'data-group' => 'common', },
     );

has_field 'common_hwBiosReleaseDate'
  => ( apply => [ Printable ],
       label => 'BIOS Release Date', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '06/17/2010',
			 'data-name' => 'ap',
			 'data-group' => 'common', },
     );

has_field 'common_hwBiosRevision'
  => ( apply => [ Printable ],
       label => 'BIOS Revision', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '8.15',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSpeedCpu'
  => ( apply => [ Printable ],
       label => 'CPU Speed', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '3100 MHz',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSpeedRam'
  => ( apply => [ Printable ],
       label => 'RAM Speed', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'comparts_ram', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '533 MHz',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwTypeIf'
  => ( type => 'Select',
       label => 'Interface Type', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_if', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Initial state of the object',
			 'autocomplete' => 'off',
			 'data-name' => 'state',
			 'data-group' => 'composite', },
       options => [{ value => '', label => '--- Choose Interface Type ---'},
		   { value => 'eth_ex', label => 'Ethernet External'},
		   { value => 'eth_in', label => 'Ethernet Internal'},
		   { value => 'wlan_ex', label => 'WiFi External'},
		   { value => 'wlan_in', label => 'WiFi Internal'},
		   { value => 'bt_ex', label => 'Bluetooth External'},
		   { value => 'bt_in', label => 'Bluetooth Internal'},
		  ],
     );

has_field 'common_hwSpeedIf'
  => ( apply => [ Printable ],
       label => 'Interface Speed', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '10/100/1000',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSize'
  => ( apply => [ Printable ],
       label => 'Size', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'some size',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSizeDisk'
  => ( apply => [ Printable ],
       label => 'Disk Size', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '500 GB',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwBus'
  => ( apply => [ Printable ],
       label => 'Bus', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'ISA, PCI, SATA, SAS, SCSI',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwMac'
  => ( apply => [ Printable ],
       label => 'MAC', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_if', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'e.g. 44:8a:5b:d4:4e:0f or 44-8A-5B-D4-4E-0F (will be normalized to 448a5bd44e0f)',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwId'
  => ( apply => [ Printable ],
       label => 'ID', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '63 0F 10 00 FF FB 8B 17',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwPartNumber'
  => ( apply => [ Printable ],
       label => 'Part Number', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'GR1333D364L9/4G000',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwVersion'
  => ( apply => [ Printable ],
       label => 'Version', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'V17.5',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwSignature'
  => ( apply => [ Printable ],
       label => 'Signature', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Family 16, Model 6, Stepping 3',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwUuid'
  => ( apply => [ Printable ],
       label => 'UUID', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '00000000-0000-0000-0000-6C626D0A5E5A',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwName'
  => ( apply => [ Printable ],
       label => 'Name', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'some name',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

has_field 'common_hwNameIf'
  => ( apply => [ Printable ],
       label => 'Interface Name', label_class => [ 'col-xs-1', ],
       wrapper_class => [  'hidden', 'relation', 'common_comparts_mb', 'common_comparts_if', ],
       element_wrapper_class => [ 'col-xs-11', 'col-lg-5', ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'eth, wlan',
			 'data-name' => 'ap',
			 'data-group' => 'singleboard', },
     );

#!!---



has_block 'group_common'
  => ( tag => 'div',
       render_list => [ 'common_description',
			'common_inventoryNumber',
			'common_hwManufacturer',
			'common_hwModel',
			'common_hwSerialNumber',
			
			'common_hwBios',
			'common_hwBiosReleaseDate',
			'common_hwBiosRevision',
			'common_hwBiosVendor',
			'common_hwBiosVersion',

			'common_hwBus',
			'common_hwSpeedCpu',
			'common_hwSizeDisk',
			'common_hwFamily',
			'common_hwFccId',
			'common_hwFirmware',
			'common_hwFirmwareType',
			'common_hwId',
			'common_hwTypeIf',
			'common_hwNameIf',
			'common_hwSpeedIf',
			'common_hwMac',
			'common_hwName',
			'common_hwPartNumber',
			'common_hwProductName',
			'common_hwSizeRam',
			'common_hwSpeedRam',
			'common_hwSignature',
			'common_hwSize',
			'common_hwSpeed',
			'common_hwUuid',
			'common_hwVersion',
			
		      ],
       attr => { id => 'group_common', class => 'qwerty', },
     );

has_block 'common'
  => ( tag => 'fieldset',
       label => 'New Inventory Data',
       render_list => [ 'group_common', ],
       class => [ 'tab-pane', 'fade', 'in', 'active', ],
       attr => { id => 'common',
		 'aria-labelledby' => "common-tab",
		 role => "tabpanel",
	       },
     );

######################################################################
#== COMPART/S ========================================================
######################################################################
has_field 'aux_add_compart'
  => ( type => 'AddElement',
       repeatable => 'compart',
       value => 'Add new compart',
       element_class => [ 'btn-success', ],
       wrapper_class => [ qw{col-lg-4 col-md-4}, ],
     );

has_field 'compart'
  => ( type => 'Repeatable',
       setup_for_js => 1,
       do_wrapper => 1,
       element_wrapper_class => [ qw{controls}, ],
       wrapper_attr => { class => 'no-has-error' },
       # wrap_repeatable_element_method => \&wrap_compart_elements,
     );

# sub wrap_compart_elements {
#   my ( $self, $input, $subfield ) = @_;
#   my $output = sprintf('%s%s%s', ! $subfield ? qq{\n<div class="duplicate">} : qq{\n<div class="duplicated">},
# 		       $input,
# 		       qq{</div>});
# }

#!!# ---
has_field 'compart.hwType'
  => ( type => 'Select',
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Compart', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { 'data-name' => 'hwtype',
			 'data-group' => 'compart', },
       empty_select => '--- Choose a Compart Type ---',
       options => [{ value => 'comparts_mb',  attributes => { 'data-relation' => 'comparts_mb' , },  label => 'Mother Board' },
		   { value => 'comparts_if',  attributes => { 'data-relation' => 'comparts_if' , },  label => 'Interface (ether, bt, wlan)' },
		   { value => 'comparts_cpu', attributes => { 'data-relation' => 'comparts_cpu', }, label => 'CPU' },
		   { value => 'comparts_ram', attributes => { 'data-relation' => 'comparts_ram', }, label => 'RAM' },
		   { value => 'comparts_disk', attributes => { 'data-relation' => 'comparts_disk', }, label => 'Disk (HDD, SSD)' },],
       # required => 1
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.hwFileDmi'
  => ( type => 'Upload',
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'DMI', label_class => [ 'col-xs-1', ],
       wrapper_class => [  qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
       element_attr => { title => 'dmidecode output',
			 'data-name' => 'hwfiledmi',
			 'data-group' => 'compart',},
       max_size => '50000',
     );

has_field 'compart.hwFileSmart'
  => ( type => 'Upload',
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'S.M.A.R.T.', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_disk}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'btn', 'btn-default', 'btn-sm', ],
       element_attr => { title => 'smartctl output',
			 'data-name' => 'hwfiledmi',
			 'data-group' => 'compart',},
       max_size => '50000',
     );

has_field 'compart.hwState'
  => ( type => 'Select',
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'State', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Initial state of the object',
			 'autocomplete' => 'off',
			 'data-name' => 'hwstate',
			 'data-group' => 'compart', },
       options => [{ value => '', label => '--- Choose State ---'},
		   { value => 'new', label => 'New' },
		   { value => 'good', label => 'Good' },
		   { value => 'bad', label => 'Bad' },
		   { value => 'broken', label => 'Broken' },
		   { value => 'burned', label => 'Burned' },
		   { value => 'gleetches', label => 'Gleetches' },],
       # required => 1,
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.inventoryNumber'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Inventory Number', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '533', 'data-name' => 'inventorynumber', 'data-group' => 'compart',},
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.description'
  => ( type => 'TextArea',
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Description', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Any description.',
			 'autocomplete' => 'off', 'data-name' => 'description', 'data-group' => 'compart',},
       cols => 30, rows => 1,
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.hwManufacturer'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Manufacturer', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Mikrotik', 'data-name' => 'hwmanufacturer', 'data-group' => 'compart',},
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.hwModel'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Model', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'RouterBOARD cAP 2n', 'data-name' => 'hwmodel', 'data-group' => 'compart',},
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.hwSerialNumber'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Serial Number', label_class => [ 'col-xs-1', ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '654705AABCD3/533', 'data-name' => 'hwserialnumber', 'data-group' => 'compart',},
       wrapper_class => [ qw{col-xs-12}, ],
     );

#!!---
has_field 'compart.hwRamSize'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'RAM Size', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '64.0MiB', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBankLocator'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Bank Locator', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'BANK0', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwSpeed'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Speed', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_ram comparts_cpu}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '400MHz', 'data-name' => 'ap', 'data-group' => 'compart', },
       wrapper_class => [ qw{col-xs-12}, ],
     );

has_field 'compart.hwProductName'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Product Name', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '880GMA-E45 (MS-7623)', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBios'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'BIOS', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'some BIOS info', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBiosVendor'
  => ( 
      label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
      label => 'BIOS Vendor', label_class => [ 'col-xs-1', ],
      wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
      element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
      element_class => [ 'input-sm', ],
      element_attr => { placeholder => 'American Megatrends Inc.', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBiosVersion'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'BIOS Version', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'V17.5', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBiosReleaseDate'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'BIOS Release Date', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '06/17/2010', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBiosRevision'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'BIOS Revision', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '8.15', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwSpeedCpu'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'CPU Speed', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_cpu}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '3100 MHz', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwSpeedRam'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'RAM Speed', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '533 MHz', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwTypeIf'
  => ( type => 'Select',
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Interface Type', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_if}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Initial state of the object',
			 'autocomplete' => 'off',
			 'data-name' => 'state',
			 'data-group' => 'composite', },
       options => [{ value => '', label => '--- Choose Interface Type ---'},
		   { value => 'eth_ex', label => 'Ethernet External'},
		   { value => 'eth_in', label => 'Ethernet Internal'},
		   { value => 'wlan_ex', label => 'WiFi External'},
		   { value => 'wlan_in', label => 'WiFi Internal'},
		   { value => 'bt_ex', label => 'Bluetooth External'},
		   { value => 'bt_in', label => 'Bluetooth Internal'},],
     );

has_field 'compart.hwSpeedIf'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Interface Speed', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_if}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '10/100/1000', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwSize'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Size', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'mini/ATX for MB, 3.5" for Disk, e.t.c.', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwSizeDisk'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Disk Size', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_disk}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '500 GB', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwBus'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Bus', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'ISA, PCI, SATA, SAS, SCSI', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwMac'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'MAC', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_if}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'e.g. 44:8a:5b:d4:4e:0f or 44-8A-5B-D4-4E-0F (will be normalized to 448a5bd44e0f)',
			 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwId'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'ID', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '63 0F 10 00 FF FB 8B 17', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwPartNumber'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Part Number', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'GR1333D364L9/4G000', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwVersion'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Version', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'V17.5', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwSignature'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Signature', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_cpu}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'Family 16, Model 6, Stepping 3', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwUuid'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'UUID', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '00000000-0000-0000-0000-6C626D0A5E5A', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwName'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Name', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'some name', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwNameIf'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Interface Name', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_if}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'eth, wlan', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwFamily'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Family', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'like CPU family', 'data-name' => 'hwfamily', 'data-group' => 'compart',},
     );

has_field 'compart.hwFccId'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'FCC ID', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'TV7RBCM2N', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwFirmware'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Firmware', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => '3.22', 'data-name' => 'ap', 'data-group' => 'compart', },
     );

has_field 'compart.hwFirmwareType'
  => ( apply => [ Printable ],
       label_class => [ qw{col-xs-12 col-sm-2 control-label}, ],
       label => 'Firmware Type', label_class => [ 'col-xs-1', ],
       wrapper_class => [ qw{col-xs-12 hidden relation comparts_mb comparts_ram comparts_if comparts_disk comparts_ram}, ],
       element_wrapper_class => [ qw{col-xs-10 col-lg-5 col-md-5}, ],
       element_class => [ 'input-sm', ],
       element_attr => { placeholder => 'ar9330L', 'data-name' => 'ap', 'data-group' => 'compart', },
     );
#!!# ---

has_field 'compart.remove'
  => ( type => 'RmElement',
       value => 'Remove this (above fields) compart',
       element_class => [ qw{btn-danger}, ],
       element_wrapper_class => [ qw{col-xs-offset-2 col-xs-10 col-lg-5 col-md-5}, ],
       wrapper_class => [ qw{well}, ],
     );

has_block 'compart'
  => ( tag => 'fieldset',
       label => 'Compart/s&nbsp;<small class="text-muted"><em>(in case, no dedicated field found, write the data to the description)</em></small>',
       render_list => [ 'aux_add_compart', 'compart', ],
       class => [ 'tab-pane', 'fade', ],
       attr => { id => 'compart',
		 'aria-labelledby' => "compart-tab",
		 role => "tabpanel", },
       wrapper_class => [ qw{col-xs-12}, ],
     );

######################################################################
#== REST OF THE FORM =================================================
######################################################################

has_field 'aux_reset'
  => ( type => 'Reset',
       element_class => [ 'btn', 'btn-danger', 'btn-block', ],
       element_wrapper_class => [ 'col-xs-12', ],
       wrapper_class => [ 'col-xs-4' ],
       # value => 'Reset All'
     );

has_field 'aux_submit'
  => ( type => 'Submit',
       element_class => [ 'btn', 'btn-success', 'btn-block', ],
       # element_wrapper_class => [ 'col-xs-12', ],
       wrapper_class => [ 'col-xs-8', ], # 'pull-right' ],
       value => 'Submit' );




######################################################################
# ====================================================================
# == VALIDATION ======================================================
# ====================================================================
######################################################################

# before 'validate_form' => sub {
#    my $self = shift;
#    if( defined $self->params->{add_inventory} &&
#        $self->params->{add_inventory} ne '' ) {
#      $self->field('common_hwType')->required(0);
#      $self->field('common_hwState')->required(0);
#      $self->field('common_hwStatus')->required(0);
#      # $self->field('common_office')->required(0);
#      # $self->field('common_title')->required(0);
#    }
#  };

sub validate {

  ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  #### ERROR if not uniq
  # DISK: S/N
  #   MB: UUID
  #  CPU: ID ???
  #   IF: MAC
  #### WARNING if not filled or stub
  #  RAM: S/N
  ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  
  my $self = shift;
  my (
      $assignedto,
      $cert_msg,
      $element,
      $elementcmp,
      $err,
      $error,
      $field,
      $is_x509,
      $ldap_crud,
      $login_error_pfx,
      $logintmp,
      $mesg,
      $passwd_acc_filter,
      $a1, $b1, $c1
     );
  
  $ldap_crud = $self->ldap_crud;
  if ( defined $self->field('common_hwAssignedTo')->value && $self->field('common_hwAssignedTo')->value ne '') {
    
    if ( $self->field('common_hwType')->value !~ /comparts_.*/ ) {

      $assignedto = $self->field('common_hwAssignedTo')->value =~ /.*,$ldap_crud->{cfg}->{base}->{acc_root}/ ?
	$self->field('common_hwAssignedTo')->value :
	sprintf('%s=%s,%s',
		$ldap_crud->{cfg}->{rdn}->{acc_root},
		$self->field('common_hwAssignedTo')->value,
		$ldap_crud->{cfg}->{base}->{acc_root});
      $mesg =
	$ldap_crud->search({ scope => 'base',
			     base => $assignedto, });
      $self->field('common_hwAssignedTo')->add_error('No such user exist!')
	if ! $mesg->count;

    } else {
      if ( $self->field('common_hwAssignedTo')->value !~ /.*,$ldap_crud->{cfg}->{base}->{inventory}/ ) {
	$self->field('common_hwAssignedTo')->add_error('For comparts objects, AssignedTo field must contain DN of the inventory object it assigned to!');
      } else {
	$mesg =
	  $ldap_crud->search({ scope => 'base',
			       base => $self->field('common_hwAssignedTo')->value, });
	$self->field('common_hwAssignedTo')->add_error('No such inventory object exist!')
	  if ! $mesg->count;
      }
    }
  }

#  if ( defined $self->field('common_hwType')->value && $self->field('common_hwAssignedTo')->value ne '') {
#  }
  # common_hwType == comparts_disk common_hwSerialNumber
  # common_hwType == comparts_mb   common_hwUuid
  # common_hwType == comparts_if   common_hwMac
  # common_hwType == comparts_ram  common_hwSerialNumber

  # compart hwType == comparts_disk compart hwSerialNumber
  # compart hwType == comparts_mb   compart hwUuid
  # compart hwType == comparts_if   compart hwMac
  # compart hwType == comparts_ram  compart hwSerialNumber

  
  # if ( $self->add_svc_acc eq '' ) {
  #   $mesg =
  #     $ldap_crud->search({ scope => 'one',
  # 			   filter => '(uid=' . $self->autologin . '*)',
  # 			   base => $ldap_crud->cfg->{base}->{acc_root},
  # 			   attrs => [ 'uid' ], });
  #   if ( $mesg->count == 1 &&
  # 	 defined $self->field('person_namesake')->value &&
  # 	 $self->field('person_namesake')->value == 1 ) {
  #     $self->namesake(1);
  #   } elsif ( $mesg->count &&
  # 	      defined $self->field('person_namesake')->value &&
  # 	      $self->field('person_namesake')->value eq '1' ) {
  #     my @uids_namesake_suffixes;
  #     foreach my $uid_namesake ( $mesg->entries ) {
  # 	push @uids_namesake_suffixes, 0+substr( $uid_namesake->get_value('uid'), length($self->autologin));
  #     }
  #     my @uids_namesake_suffixes_desc = sort {$b <=> $a} @uids_namesake_suffixes;
  #     # @uids_namesake_suffixes_desc;
  #     $self->namesake(++$uids_namesake_suffixes_desc[0]);
  #   } elsif ( $mesg->count ) {
  #     $self->field('person_login')->add_error('Auto-generaged variant for login exiscts!');
  #   } else {
  #     $self->namesake('');
  #   }
  # } else {
  #   $self->namesake('');
  # }

  # # not simplified variant start
  # if ( ! defined $self->field('person_simplified')->value ||
  #      $self->field('person_simplified')->value ne '1' ) {
  #   #----------------------------------------------------------
  #   #-- VALIDATION for services with password -----------------
  #   #----------------------------------------------------------
  #   my $i = 0;
  #   foreach $element ( $self->field('compart')->fields ) {
  #     # if ( $#{$self->field('compart')->fields} > -1 &&

  #     # new user, defined neither fqdn nor svc, but login
  #     if ( $self->add_svc_acc eq '' &&
  # 	   defined $element->field('login')->value &&
  # 	   $element->field('login')->value ne '' &&
  # 	   ((! defined $element->field('authorizedservice')->value &&
  # 	     ! defined $element->field('associateddomain')->value ) ||
  # 	    ( $element->field('authorizedservice')->value eq '' &&
  # 	      $element->field('associateddomain')->value eq '' )) ) {
  # 	$element->field('associateddomain')->add_error('Domain Name is mandatory!');
  # 	$element->field('authorizedservice')->add_error('Service is mandatory!');
	
  #     } elsif ( defined $element->field('authorizedservice')->value &&
  # 		$element->field('authorizedservice')->value ne '' &&
  # 		( ! defined $element->field('associateddomain')->value ||
  # 		  $element->field('associateddomain')->value eq '' ) ) { # no fqdn
  # 	$element->field('associateddomain')->add_error('Domain Name is mandatory!');
  #     } elsif ( defined $element->field('associateddomain')->value &&
  # 		$element->field('associateddomain')->value ne '' &&
  # 		( ! defined $element->field('authorizedservice')->value ||
  # 		  $element->field('authorizedservice')->value eq '' )) { # no svc
  # 	$element->field('authorizedservice')->add_error('Service is mandatory!');
  #     }

  #     if ( ( defined $element->field('password1')->value &&
  # 	     ! defined $element->field('password2')->value ) ||
  # 	   ( defined $element->field('password2')->value &&
  # 	     ! defined $element->field('password1')->value ) ) { # only one pass
  # 	$element->field('password1')->add_error('Both or none passwords have to be defined!');
  # 	$element->field('password2')->add_error('Both or none passwords have to be defined!');
  #     }

  #     #---[ login preparation for check ]------------------------------------------------
  #     if ( ! defined $element->field('login')->value ||
  # 	   $element->field('login')->value eq '' ) {
  # 	$logintmp = sprintf('%s%s%s',
  # 			    defined $ldap_crud
  # 			    ->cfg
  # 			    ->{authorizedService}
  # 			    ->{$element->field('authorizedservice')->value}
  # 			    ->{login_prefix} ?
  # 			    $ldap_crud->cfg
  # 			    ->{authorizedService}
  # 			    ->{$element->field('authorizedservice')->value}
  # 			    ->{login_prefix} : '',
  # 			    $self->autologin,
  # 			    $self->namesake);
  # 	$login_error_pfx = 'Login (autogenerated, since empty)';
  #     } else {
  # 	$logintmp = sprintf('%s%s',
  # 			    defined $ldap_crud
  # 			    ->cfg
  # 			    ->{authorizedService}
  # 			    ->{$element->field('authorizedservice')->value}
  # 			    ->{login_prefix} ?
  # 			    $ldap_crud->cfg
  # 			    ->{authorizedService}
  # 			    ->{$element->field('authorizedservice')->value}
  # 			    ->{login_prefix} : '',
  # 			    $element->field('login')->value);
  # 	$login_error_pfx = 'Login';
  #     }

  #     $passwd_acc_filter = '(uid=' . $logintmp . '@' . $element->field('associateddomain')->value . ')'
  # 	if defined $element->field('associateddomain')->value && $element->field('associateddomain')->value ne '';
  #     #---[ login preparation for check ]------------------------------------------------

  #     #---[ 802.1x ]------------------------------------------------
  #     if ( defined $element->field('authorizedservice')->value &&
  # 	   $element->field('authorizedservice')->value =~ /^802.1x-.*$/ ) {

  # 	if ( $element->field('authorizedservice')->value =~ /^802.1x-mac$/ ) {
  # 	  $element->field('login')->add_error('MAC address is mandatory!')
  # 	    if ! defined $element->field('login')->value || $element->field('login')->value eq '';
  # 	  $element->field('login')->add_error('MAC address is not valid!')
  # 	    if defined $element->field('login')->value && $element->field('login')->value ne '' &&
  # 	    ! $self->macnorm({ mac => $element->field('login')->value });
  # 	  $logintmp = $self->macnorm({ mac => $element->field('login')->value });
  # 	  $login_error_pfx = 'MAC';
  # 	  $passwd_acc_filter = '(cn=' . $logintmp . ')';
  # 	}

  # 	if ( $element->field('authorizedservice')->value eq '802.1x-eap-tls' ) {
  # 	  if ( defined $element->field('userCertificate')->value &&
  # 	       ref($element->field('userCertificate')->value) eq 'HASH' ) {
  # 	    $cert = $self->file2var( $element->field('userCertificate')->value->{tempname}, $cert_msg);
  # 	    $element->field('userCertificate')->add_error($cert_msg->{error})
  # 	      if defined $cert_msg->{error};
  # 	    $is_x509 = $self->cert_info({ cert => $cert });
  # 	    $element->field('userCertificate')->add_error('Certificate file is broken or not DER format!')
  # 	      if defined $is_x509->{error};
  # 	    $element->field('userCertificate')->add_error('Problems with certificate file');
  # 	    $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				  '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
  # 				  '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
  # 				  'Problems with certificate file<br>' .
  # 				  $is_x509->{error})
  # 	      if defined $is_x509->{error};
  # 	  } elsif ( defined $element->field('userCertificate')->value &&
  # 		    ! defined $element->field('userCertificate')->value->{tempname} ) {
  # 	    $element->field('userCertificate')->add_error('userCertificate file was not uploaded');
  # 	    $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				  '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
  # 				  '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
  # 				  'userCertificate file was not uploaded<br>');
  # 	  } elsif ( ! defined $element->field('userCertificate')->value ) {
  # 	    $element->field('userCertificate')->add_error('userCertificate is mandatory!');
  # 	    $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				  '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
  # 				  '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
  # 				  'userCertificate is mandatory!<br>');
  # 	  }
  # 	  $logintmp = 'rad-' . $element->field('login')->value;
  # 	}
  # 	if (( ! defined $element->field('radiusgroupname')->value ||
  # 	      $element->field('radiusgroupname')->value eq '' ) &&
  # 	    ( ! defined $element->field('radiusprofiledn')->value ||
  # 	      $element->field('radiusprofiledn')->value eq '' )) {
  # 	  $element->field('radiusgroupname')->add_error('RADIUS group, profile or both are to be set!');
  # 	  $element->field('radiusprofiledn')->add_error('RADIUS profile, group or both are to be set!');
  # 	}
  # 	if ( defined $element->field('radiusgroupname')->value &&
  # 	     $element->field('radiusgroupname')->value ne '' ) {
  # 	  $mesg =
  # 	    $ldap_crud
  # 	    ->search({ base => $element->field('radiusgroupname')->value,
  # 		       filter => sprintf('member=uid=%s,authorizedService=%s@%s,%s',
  # 					 $logintmp,
  # 					 $element->field('authorizedservice')->value,
  # 					 $element->field('associateddomain')->value,
  # 					 $self->add_svc_acc)
  # 		     });
  # 	  $element->field('radiusgroupname')
  # 	    ->add_error(sprintf('<span class="mono">%s</span> already is in this RADIUS group.<br>This service object <span class="mono">%s</span> either was deleted but not removed from, or is still the member of the group.',
  # 				$logintmp,
  # 				sprintf('uid=%s,authorizedService=%s@%s,%s',
  # 					$logintmp,
  # 					$element->field('authorizedservice')->value,
  # 					$element->field('associateddomain')->value,
  # 					$self->add_svc_acc)))
  # 	    if $mesg->count;
  # 	}
  #     }
  #     #---[ 802.1x ]------------------------------------------------

  #     # prepare to know if login+service+fqdn is uniq?
  #     if ( ! $i ) {   # && defined $element->field('login')->value ) {
  # 	$elementcmp
  # 	  ->{$logintmp .
  # 	     $element->field('authorizedservice')->value .
  # 	     $element->field('associateddomain')->value} = 1;
  #     } else { #if ( $i && defined $element->field('login')->value ) {
  # 	$elementcmp
  # 	  ->{$logintmp .
  # 	     $element->field('authorizedservice')->value .
  # 	     $element->field('associateddomain')->value}++;
  #     }

  #     if ( defined $element->field('authorizedservice')->value && $element->field('authorizedservice')->value ne '' &&
  # 	   defined $element->field('associateddomain')->value && $element->field('associateddomain')->value ne '' ) {
  # 	$mesg =
  # 	  $ldap_crud->search({
  # 			      filter => '(&(authorizedService=' .
  # 			      $element->field('authorizedservice')->value . '@' . $element->field('associateddomain')->value .
  # 			      ')' . $passwd_acc_filter .')',
  # 			      base => $ldap_crud->cfg->{base}->{acc_root},
  # 			      attrs => [ 'uid' ],
  # 			     });
  # 	$element->field('login')->add_error($login_error_pfx . ' <mark>' . $logintmp . '</mark> is not available!')
  # 	  if ($mesg->count);
  #     }

  #     $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 			    '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 			    '<i class="fa fa-user pull-right fa-stack-1x"></i></span>' .
  # 			    '<b class="visible-lg-inline">&nbsp;Pass&nbsp;</b>' .
  # 			    'Has error/s! Correct or remove, please')
  # 	if $self->field('compart')->has_error_fields;

  #     $i++;
  #   }
  #   # error rising if login+service+fqdn not uniq
  #   $i = 0;
  #   foreach $element ( $self->field('compart')->fields ) {
  #     if ( defined $element->field('authorizedservice')->value &&
  # 	   $element->field('authorizedservice')->value ne '' &&
  # 	   defined $element->field('associateddomain')->value &&
  # 	   $element->field('associateddomain')->value ne '' ) {
  # 	$element->field('login')
  # 	  ->add_error(sprintf('%s <mark>%s</mark> defined more than once for the same service and FQDN',
  # 			      $login_error_pfx, $logintmp))
  # 	  if defined $elementcmp->{$logintmp .
  # 				   $element->field('authorizedservice')->value .
  # 				   $element->field('associateddomain')->value} &&
  # 				     $elementcmp->{ $logintmp .
  # 						    $element->field('authorizedservice')->value .
  # 						    $element->field('associateddomain')->value
  # 						  } > 1;
  #     }
  #     $i++;
  #   }
  
  #   #----------------------------------------------------------
  #   #== VALIDATION password less ------------------------------
  #   #----------------------------------------------------------
  
  #   #---[ ssh + ]------------------------------------------------
  #   my $sshpubkeyuniq;
  #   $i = 0;
  #   foreach $element ( $self->field('loginless_ssh')->fields ) {
  #     if ( defined $element->field('associateddomain')->value &&
  # 	   ! defined $element->field('key')->value &&
  # 	   ! defined $element->field('keyfile')->value ) { # fqdn but no key
  # 	$element->field('key')->add_error('Either Key, KeyFile or both field/s have to be defined!');
  # 	$element->field('keyfile')->add_error('Either KeyFile, Key or both field/s have to be defined!');
  #     } elsif ( ( defined $element->field('key')->value ||
  # 		  defined $element->field('keyfile')->value ) &&
  # 		! defined $element->field('associateddomain')->value ) { # key but no fqdn
  # 	$element->field('associateddomain')->add_error('Domain field have to be defined!');
  #     } elsif ( ! defined $element->field('key')->value &&
  # 		! defined $element->field('keyfile')->value &&
  # 		! defined $element->field('associateddomain')->value &&
  # 		$i > 0 ) {	# empty duplicatee
  # 	$self->add_form_error('<span class="fa-stack fa-fw">' .
  # 			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 			      '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Empty duplicatee! Fill it or remove, please');
  #     }

  #     # prepare to know if fqdn+key+keyfile is uniq?
  #     $sshpubkeyuniq->{associateddomain} = defined $element->field('associateddomain')->value ?
  # 	$element->field('associateddomain')->value : '';
  #     $sshpubkeyuniq->{key} = defined $element->field('key')->value ?
  # 	$element->field('key')->value : '';
  #     $sshpubkeyuniq->{keyfile} = defined $element->field('keyfile')->value ?
  # 	$element->field('keyfile')->value->{filename} : '';
  #     $sshpubkeyuniq->{hash} = sprintf('%s%s%s',
  # 				       $sshpubkeyuniq->{associateddomain},
  # 				       $sshpubkeyuniq->{key},,
  # 				       $sshpubkeyuniq->{keyfile});
  #     $elementcmp->{$sshpubkeyuniq->{hash}} = ! $i ? 1 : $elementcmp->{$sshpubkeyuniq->{hash}}++;

  #     # validate keyfile if provided
  #     my $sshpubkey_hash = {};
  #     my ( $sshpubkey, $key_file, $key_file_msg );
  #     if ( defined $element->field('keyfile')->value &&
  # 	   ref($element->field('keyfile')->value) eq 'Catalyst::Request::Upload' ) {
  # 	$key_file = $self->file2var( $element->field('keyfile')->value->{tempname}, $key_file_msg, 1);
  # 	$element->field('keyfile')->add_error($key_file_msg->{error})
  # 	  if defined $key_file_msg->{error};
  # 	foreach (@{$key_file}) {
  # 	  my $abc = $_;
  # 	  if ( ! $self->sshpubkey_parse(\$abc, $sshpubkey_hash) ) {
  # 	    $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				  '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 				  '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 				  '<b> <i class="fa fa-arrow-right"></i> SSH:</b> ' . $sshpubkey_hash->{error});
  # 	  }
  # 	  $sshpubkey_hash = {};
  # 	}
  #     }
      
  #     $sshpubkey = defined $element->field('key')->value ? $element->field('key')->value : undef;
  #     if( defined $sshpubkey && ! $self->sshpubkey_parse(\$sshpubkey, $sshpubkey_hash) ) {
  # 	$self->add_form_error('<span class="fa-stack fa-fw">' .
  # 			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 			      '<b> <i class="fa fa-arrow-right"></i> SSH:</b> ' . $sshpubkey_hash->{error});
  #     }
  #     $i++;
  #   }

  #   foreach $element ( $self->field('loginless_ssh')->fields ) {
  #     $sshpubkeyuniq->{associateddomain} = defined $element->field('associateddomain')->value ?
  # 	$element->field('associateddomain')->value : '';
  #     $sshpubkeyuniq->{key} = defined $element->field('key')->value ?
  # 	$element->field('key')->value : '';
  #     $sshpubkeyuniq->{keyfile} = defined $element->field('keyfile')->value ?
  # 	$element->field('keyfile')->value->{filename} : '';
  #     $sshpubkeyuniq->{hash} = sprintf('%s%s%s',
  # 				       $sshpubkeyuniq->{associateddomain},
  # 				       $sshpubkeyuniq->{key},,
  # 				       $sshpubkeyuniq->{keyfile});
  #     $element->field('key')->add_error('The same key is defined more than once for the same FQDN')
  # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
  # 	$sshpubkeyuniq->{keyfile} eq '' &&
  # 	$sshpubkeyuniq->{key} ne '';
  #     $element->field('keyfile')->add_error('The same keyfile is defined more than once for the same FQDN')
  # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
  # 	$sshpubkeyuniq->{key} eq '' &&
  # 	$sshpubkeyuniq->{keyfile} ne '';
  #     $element->field('key')->add_error('The same key and keyfile are defined more than once for the same FQDN')
  # 	if $elementcmp->{$sshpubkeyuniq->{hash}} > 1 &&
  # 	$sshpubkeyuniq->{keyfile} ne '' &&
  # 	$sshpubkeyuniq->{key} ne '';
  #   }

  #   $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 			  '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 			  '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 			  '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 			  '<b> <i class="fa fa-arrow-right"></i> SSH:</b> Has error/s! Correct or remove, please')
  #     if $self->field('loginless_ssh')->has_error_fields;
  
  #   #---[ ssh - ]------------------------------------------------

  #   #---[ OpenVPN + ]--------------------------------------------
  #   $i = 0;
  #   foreach $element ( $self->field('loginless_ovpn')->fields ) {
  #     if ((( defined $element->field('associateddomain')->value &&
  # 	     defined $element->field('userCertificate')->value &&
  # 	     defined $element->field('ifconfigpush')->value &&
  # 	     ( $element->field('associateddomain')->value eq '' ||
  # 	       $element->field('userCertificate')->value eq '' ||
  # 	       $element->field('ifconfigpush')->value eq '' ) ) ||
  # 	   ( ! defined $element->field('associateddomain')->value ||
  # 	     ! defined $element->field('userCertificate')->value ||
  # 	     ! defined $element->field('ifconfigpush')->value  )) && $i > 0 ) {
  # 	$element->field('associateddomain')->add_error('');
  # 	$element->field('userCertificate')->add_error('');
  # 	$element->field('ifconfigpush')->add_error('');
  #     }
    
  #     if ( ! defined $element->field('associateddomain')->value &&
  # 	   ! defined $element->field('userCertificate')->value &&
  # 	   ! defined $element->field('ifconfigpush')->value &&
  # 	   $i > 0 ) {	   # empty duplicate (repeatable)
  # 	# $element->add_error('Empty duplicatee!');
  # 	$self->add_form_error('<span class="fa-stack fa-fw">' .
  # 			      '<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 			      '<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 			      '<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 			      '<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Empty duplicatee! Fill it or remove, please');
  #     }

  #     if ( defined $element->field('associateddomain')->value &&
  # 	   defined $element->field('status')->value &&
  # 	   defined $element->field('ifconfigpush')->value &&
  # 	   ( $element->field('associateddomain')->value ne '' ||
  # 	     $element->field('status')->value ne '' ||
  # 	     $element->field('ifconfigpush')->value ne '' ) ) {
  # 	if ( defined $element->field('userCertificate')->value &&
  # 	     ref($element->field('userCertificate')->value) eq 'HASH' ) {
  # 	  $cert = $self->file2var( $element->field('userCertificate')->value->{tempname}, $cert_msg);
  # 	  $element->field('userCertificate')->add_error($cert_msg->{error})
  # 	    if defined $cert_msg->{error};
  # 	  $is_x509 = $self->cert_info({ cert => $cert });
  # 	  $element->field('userCertificate')->add_error('Certificate file is broken or not DER format!')
  # 	    if defined $is_x509->{error};
  # 	  $element->field('userCertificate')->add_error('Problems with certificate file');
  # 	  $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Problems with certificate file<br>' . $is_x509->{error})
  # 	    if defined $is_x509->{error};
  # 	} elsif ( defined $element->field('userCertificate')->value &&
  # 		  ! defined $element->field('userCertificate')->value->{tempname} ) {
  # 	  $element->field('userCertificate')->add_error('userCertificate file was not uploaded');
  # 	  $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> userCertificate file was not uploaded<br>');
  # 	} elsif ( ! defined $element->field('userCertificate')->value ) {
  # 	  $element->field('userCertificate')->add_error('userCertificate is mandatory!');
  # 	  $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 				'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 				'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 				'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 				'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> userCertificate is mandatory!<br>');
  # 	}
  #     }


  #     #
  #     ## !!! add check for this cert existance !!! since when it is absent, PSGI falls
  #     #

  #     $i++;
  #   }

  # $self->add_form_error('<span class="fa-stack fa-fw">' .
  # 			'<i class="fa fa-cog fa-stack-2x text-muted umi-opacity05"></i>' .
  # 			'<i class="fa fa-user-times pull-right fa-stack-1x"></i></span>' .
  # 			'<b class="visible-lg-inline">&nbsp;NoPass&nbsp;</b>' .
  # 			'<b> <i class="fa fa-arrow-right"></i> OpenVPN:</b> Has error/s! Correct or remove, please')
  #   if $self->field('loginless_ovpn')->has_error_fields;
  # #---[ OpenVPN - ]--------------------------------------------

  # }
  # # not simplified variant stop
}

######################################################################

sub offices {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_organizations;
}

sub associateddomains {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_associateddomains;
}

sub authorizedservice {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_authorizedservice;
}

sub radgroup {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_radgroup;
}

sub radprofile {
  my $self = shift;
  return unless $self->form->ldap_crud;
  return $self->form->ldap_crud->select_radprofile;
}

######################################################################


no HTML::FormHandler::Moose;

__PACKAGE__->meta->make_immutable;

1;
