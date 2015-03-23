$(function(){
    $('#groups').multiSelect({
	keepOrder: true,

	selectableHeader: "<button type='button' class='btn btn-block btn-info btn-sm'><span class='fa fa-group'>&nbsp;</span><b>Groups Available</b></button><input type='text' class='form-control search-input input-sm' autocomplete='off' placeholder='type to search or clear all for default'>",
	selectionHeader: "<button type='button' class='btn btn-block btn-success btn-sm'><span class='fa fa-group'>&nbsp;</span><b>Groups Selected</b></button><input type='text' class='form-control search-input input-sm' autocomplete='off' placeholder='type to search or clear all for default'>",

	afterInit: function(ms){
	    var that = this,
		$selectableSearch = that.$selectableUl.prev(),
		$selectionSearch = that.$selectionUl.prev(),
		selectableSearchString = '#'+that.$container.attr('id')+' .ms-elem-selectable:not(.ms-selected)',
		selectionSearchString = '#'+that.$container.attr('id')+' .ms-elem-selection.ms-selected';

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

// here we put multiselect related things into tab
$(function(){
    var element = document.getElementById("ms-groups");
    element.classList.add("tab-pane");
});
