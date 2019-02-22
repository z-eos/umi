$(function(){
    $('.umi-multiselect').multiSelect({
	keepOrder: true,

	selectableHeader: "<div class='input-group has-warning'><div class='input-group-prepend'><span class='input-group-text bg-warning' id='basic-addon1' title='Available groups search'><i class='fas fa-users text-light'></i></span></div><input type='text' autocomplete='off' aria-describedby='basic-addon1' class='form-control search-input input-sm' placeholder='Search for available' title='Search for available'></div>",
	selectionHeader: "<div class='input-group has-success'><div class='input-group-prepend'><span class='input-group-text bg-success' id='basic-addon2' title='Available groups search'><i class='fas fa-users text-light'></i></span></div><input type='text' autocomplete='off' aria-describedby='basic-addon2' class='form-control search-input input-sm' placeholder='Search for selected' title='Search for selected'></div>",

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
    // $('#ms-groups').addClass('tab-panel');
});

// here we put multiselect related things into tab
$(function(){
    var element = document.getElementById("ms-groups");
    element.classList.add("tab-pane");
});
