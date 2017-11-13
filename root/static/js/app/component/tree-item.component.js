Vue.component('tree-item', {
    template: '#template-tree-item',

    props: ['tree'],

    data: function () {
        return {
            opened: false
        }
    },

    methods: {
        toggle: function () {
            this.opened = !this.opened;
        },

        checkBranches: function () {
            var _this = this;

            if ( this.tree.subtree ) {
                this.toggle();
            } else {
                Service.api.getTreeData( this.tree.dn, function (data) {
		    if ( !data.tree.subtree ) { 
			return;
		    }
                    data.tree.subtree.forEach(function (tree) {
			if ( tree.subtree ) {
                            tree.subtree = tree.subtree.sort(function (prev, next) {
				return prev.id > next.id ? 1 : -1
                            })
			}
                    });
		    
                    _this.$set(_this.tree, 'subtree', data.tree.subtree);
                    _this.opened = true;
                });
            }
        },

	showItem: function () {
            Service.api.updateViewTree(this.tree.dn);
        },

	showItemBranch: function () {
            Service.api.updateViewTree(this.tree.dn, true);
        }

	
    }
});
