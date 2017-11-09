new Vue({
    el: '#App',
    
    data: function () {
        return {
            tree: {},
            config: {}
        }
    },

    mounted: function () {
        this.getTreeData();
    },

    methods: {
        getTreeData: function () {
            var _this = this;

            Service.api.getTreeData(null, function (data) {
                data.tree.subtree.forEach(function (tree) {
		    if ( tree.subtree ) {
			tree.subtree = tree.subtree.sort(function (prev, next) {
                            return prev.id > next.id ? 1 : -1
			})
		    }
                });

                _this.$data.tree = data.tree;
            });
        }
    }
})
