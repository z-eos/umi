Vue.component('tree', {
    template: '#template-tree',

    // data: function () {
    	// return {
    	// 	search: ''
    	// }
    // },

    props: ['tree'],

    computed: {
    	// filteredTree: function () {
    	// 	var _this = this;

    	// 	if ( !this.tree || !this.tree.length ) {
    	// 		return [];
    	// 	};

    	// 	function checkItem (text) {
    	// 		return text.toLowerCase().indexOf(_this.search.toLowerCase()) >= 0;
    	// 	};


    	// 	return this.tree.filter(function (item) {
    	// 		return item.dn.toLowerCase().indexOf(_this.search.toLowerCase()) >= 0;
    	// 	});
    	// }		
    }
});