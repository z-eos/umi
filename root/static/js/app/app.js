
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
                _this.tree = data;
            });
        }
    }
})
