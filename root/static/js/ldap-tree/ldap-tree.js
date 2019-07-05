// define the tree-item component
Vue.component('ldap-tree-item', {
    template: '#item-template',
    props: {
	item: Object
    },
    data: function () {
	return { isOpen: this.item.isOpen }
    },
    computed: {
	isFolder: function () {
	    return this.item.children && this.item.children.length
	}
    },
    methods: {
	toggleItem: function () {
	    if (this.isFolder) {
		this.item.isOpen = !this.item.isOpen
	    }
	},
	setState: function (branch, isOpen) {
	    var self = this;
	    branch.isOpen = isOpen;
	    if ( branch.children ) {
		branch.children.forEach( function(item) {self.setState(item, isOpen)} )
	    }
	},
	toggleTree: function () {
	    //debugger;
	    if (this.isFolder) {
		this.setState(this.item, !this.item.isOpen)
	    }
	},
	makeFolder: function () {
	    if (!this.isFolder) {
      		this.$emit('make-folder', this.item)
		this.isOpen = true
	    }
	},
	showItem: function (scope) {
	    // console.log(this.item.dn);
	    var url = scope ?
		'/searchby?ldapsearch_scope=sub&ldapsearch_base='  + this.item.dn :
		'/searchby?ldapsearch_scope=base&ldapsearch_base=' + this.item.dn;

	    $.ajax({
		url: url,
		success: function (html) {
		    $('#workingfield').html(html);
		    handleResponce();
		}
	    });
	    // console.log('showItem scope:', scope);
	}
    }
});


// boot up
var ldapTree = new Vue({
    el: '#ldap-tree',

    data: function () {
        return { tree: {} }
    },
    
    mounted: function () {
	var _this = this;
	$.ajax({
	    type: "GET",
	    url: '/ldap_tree/ldap_tree_neo',
	    success: function (data) {		
		if (typeof data === 'string') {
		    // console.log('data is string')
		    JSON.parse(data)
		} else if (typeof data === 'object') {
		    // console.log('data is object')
		    data = data.json_tree
		    // console.log(data)
		} else {
		    console.warn("Data has unusable format - ", typeof data)
		    return
		}
		sortRecursively(data);	
		_this.tree = data;
	    },
	    error: function (error) {
		console.warn('Request faild - ', error)
	    }
	});	
    },
    
    methods: {
	makeFolder: function (item) {
    	    Vue.set(item, 'children', [])
	}
    }
});


const compareFunc = (a, b) => {
    const aVal = a.name.toLowerCase();
    const bVal = b.name.toLowerCase();
    if (aVal === bVal) return 0;
    return aVal > bVal ? 1 : -1;
};

const sortRecursively = arr => {
    if (arr.children) {
      arr.children = arr.children.map(sortRecursively).sort(compareFunc);
    }
    return arr;
  };
