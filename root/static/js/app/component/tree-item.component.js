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
		    if ( !data.tree.dn ) { 
			return;
		    }
		    
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
