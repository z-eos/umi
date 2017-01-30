
 var table = $('#dataTableToDraw').DataTable({
   "dom": '<"well clearfix"i><"clearfix"<"pull-left btn-group"B><"pull-right"f>>rt<"clearfix"<"pull-left"l><"pull-right"p>>',
   "buttons": {
     "buttons": [
       {
	 extend: 'copy',
	 text: '<i title="Copy current page data to clipboard" class="fa fa-copy fa-lg"></i>',
	 className: 'btn btn-info',
	 exportOptions: {
           modifier: {
             page: 'current'
           }
         },
       },
       {
	 extend: 'print',
	 text: '<i title="Print current page" class="fa fa-print fa-lg"></i>',
	 className: 'btn btn-info',
	 autoPrint: false,
	 exportOptions: {
           modifier: {
             page: 'current'
           }
         },
       },
       {
	 extend: 'csv',
	 text: '<i title="Download current page as CSV file" class="fa fa-download fa-lg"></i>',
	 className: 'btn btn-info',
	 exportOptions: {
           modifier: {
             page: 'current'
           }
         },
       },
     ]
   },
   "renderer": "bootstrap",
   "responsive": true,
   "order": [[ 2, 'desc' ]],
   //"displayLength": 25,
   "lengthMenu": [[10, 25, 50, 100, -1], [10, 25, 50, 100, "All"]],
   "drawCallback": function ( settings ) {
     var api = this.api();
     var rows = api.rows( {page:'current'} ).nodes();
     var last=null;
     
     api.column(5, {page:'current'} ).data().each( function ( group, i ) {
       if ( last !== group ) {
         $(rows).eq( i ).before(
           '<tr class="success group"><td colspan="8" class="text-muted"><b>'+group+'</b></td></tr>'
         );
         last = group;
       }
     } );
   },
   "infoCallback": function( settings, start, end, max, total, pre ) {
     var infostr= start +' to '+ end +' of '+ total +' selected records from all, '+ max +' rows';
     return infostr;
   },
   "createdRow": function ( row, data, index ) {
     if ( data[2] == 1 ) {
       $(row).addClass('danger');
     }
   },
 } );

 // Order by the grouping
 $('#accounts tbody').on( 'click', 'tr.group', function () {
   var currentOrder = table.order()[0];
   if ( currentOrder[0] === 2 && currentOrder[1] === 'asc' ) {
     table.order( [ 2, 'desc' ] ).draw();
   }
   else {
     table.order( [ 2, 'asc' ] ).draw();
   }
 } );
