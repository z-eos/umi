$.fn.sort = function (sortType) {
    return $(this).each(function () {
	$(this).append($(this).find('div.dropdown-item').get().sort(function (el1, el2) {
	    return typeof sortType === 'function' ? sortType( $(el1), $(el2) ) : false;	
	}));
    })
};

var sortFn = {
    byOrder: function (el1, el2) {
	return el1.find('[data-order]').data('order') > el2.find('[data-order]').data('order');
    }
}

$('.dropdown-menu').sort( sortFn.byOrder );
