$(function(){
    $('.umi-multiselect').each(function() {
	var $umiMultiselect = $(this);
	var icoL;
	var icoR;
	var colL;
	var colR;
	var plhL = 'Search for available';
	var plhR = 'Search for selected';

	if ( $umiMultiselect.data('placeholder') ) {
	    plhL += " " + $umiMultiselect.data('placeholder');
	    plhR += " " + $umiMultiselect.data('placeholder');
	}
	
	icoL = $umiMultiselect.data('ico-l') ? $umiMultiselect.data('ico-l') : 'fa-users';
	icoR = $umiMultiselect.data('ico-r') ? $umiMultiselect.data('ico-r') : 'fa-users';

	colL = $umiMultiselect.data('col-l') ? $umiMultiselect.data('col-l') : 'bg-info';
	colR = $umiMultiselect.data('col-r') ? $umiMultiselect.data('col-r') : 'bg-success';
	
	$umiMultiselect.multiSelect({
	    keepOrder: true,

	    selectableHeader: "<div class='input-group has-warning'><div class='input-group-prepend'><span class='input-group-text " + colL + "' id='basic-addon1' title='" + plhL + "'><i class='fas " + icoL + " text-light'></i></span></div><input type='text' autocomplete='off' aria-describedby='basic-addon1' class='form-control search-input input-sm' placeholder='" + plhL + "' title='" + plhL + "'></div>",
	    selectionHeader: "<div class='input-group has-success'><div class='input-group-prepend'><span class='input-group-text " + colR + "' id='basic-addon2' title='" + plhR + "'><i class='fas " + icoR + " text-light'></i></span></div><input type='text' autocomplete='off' aria-describedby='basic-addon2' class='form-control search-input input-sm' placeholder='" + plhR + "' title='" + plhR + "'></div>",

	    afterInit: function(ms){
		var that = this,
		    $selectableSearch = that.$selectableUl.prev().find('input'),
		    $selectionSearch  = that.$selectionUl.prev().find('input'),
		    selectableSearchString = '#'+that.$container.attr('id')+' .ms-elem-selectable:not(.ms-selected)',
		    selectionSearchString  = '#'+that.$container.attr('id')+' .ms-elem-selection.ms-selected';

		that.qs1 = $selectableSearch.quicksearch(selectableSearchString)
		    .on('keydown', function(e){
			if (e.which === 40){
			    that.$selectableUl.focus();
			    return false;
			}
		    });

		that.qs2 = $selectionSearch.quicksearch(selectionSearchString)
		    .on('keydown', function(e){
			if (e.which == 40){
			    that.$selectionUl.focus();
			    return false;
			}
		    });
	    },
	    afterSelect: function(){
		this.qs1.cache();
		this.qs2.cache();
	    },
	    afterDeselect: function(){
		this.qs1.cache();
		this.qs2.cache();
	    }

	    /* var element = document.getElementById("ms-groups");
	       element.classList.add("tab-pane"); */
	    
	});
    });
});

// here we put multiselect related things into tab
$(function(){
    var element = document.getElementById("ms-groups");
    element.classList.add("tab-pane");
});

