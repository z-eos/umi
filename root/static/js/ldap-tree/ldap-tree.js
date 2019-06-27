var treeData = $.ajax({
    type: "GET",
    url: '/ldap_tree/ldap_tree_neo',
    success: function (data) {

	if (typeof data === 'string') {
	    // console.log('data is string');
	    JSON.parse(data);
	} else if (typeof data === 'object') {
	    // console.log('data is object');
	    data = data.json_tree
	    // console.log(data);
	} else {
	    console.warn("Data has unusable format - ", typeof data);
	    return;
	}

	sortRecursively(data)
	// should be here, othervise data returns after Vue init
	bootUpDemo(data);
	
    },
    error: function (error) {
	console.warn('Request faild - ', error);
    }
});

// define the tree-item component
Vue.component('ldap-tree-item', {
    template: '#item-template',
    props: {
	item: Object
    },
    data: function () {
	return {
	    isOpen: false
	}
    },
    computed: {
	isFolder: function () {
	    return this.item.children && this.item.children.length
	}
    },
    methods: {
	toggle: function () {
	    if (this.isFolder) {
		this.isOpen = !this.isOpen
	    }
	},
	makeFolder: function () {
	    if (!this.isFolder) {
      		this.$emit('make-folder', this.item)
		this.isOpen = true
	    }
	},
	showItem: function (scope) {
	    console.log(this.item.dn);
	    // var url = this.isFolder ?
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
	}
    }
});


// boot up the demo
const bootUpDemo = function (data){
    // console.log(data);
    var demo = new Vue({
	el: '#ldap-tree',
	data: {
	    treeData: data
	},
	methods: {
	    makeFolder: function (item) {
    		Vue.set(item, 'children', [])
		this.addItem(item)
	    },
	    addItem: function (item) {
    		item.children.push({
		    name: 'new stuff'
		})
	    }
	}
    })
};

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
