
Vue.component('tree-item', {
    template: '#template-tree-item',

    props: ['item'],

    data: function () {
        return {
            opened: false,
            loading: false,
            hasSubItems: false,
            branches: []
        }
    },

    methods: {
        toggle: function () {
            this.opened = !this.opened;
        },

        loadBranches: function (callBack) {
            var _this = this;

            if ( this.loading ) {
                return;
            }

            this.loading = true;

            Service.api.getTreeData(this.item.dn, function (branches) {
                _this.branches = branches;
                _this.loading = false;
            });
        },

        openBranches: function () {
            if( this.item.branch < 1 ) {
               return;
            }

            this.opened = true;

            if ( this.branches.length === 0 ) {
                this.loadBranches();
            }
        },

        closeBranches: function () {
            if( this.item.branch < 1 ) {
                return;
            }
            
            this.opened = false;
        },

        toggleBranches: function () {
            (this.opened ? this.closeBranches : this.openBranches)();
        },

        showItem: function () {
            Service.api.updateViewTree(this.item.dn);
        },

        showItemBranches: function () {
            Service.api.updateViewTree(this.item.dn, true);
        }
    }
});
