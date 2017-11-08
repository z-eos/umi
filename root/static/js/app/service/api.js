window.Service = window.Module || {};

window.Service.api = (function () {

    function Api() {
        var config = this.config = {};

        config.rootElement = $('#App');
        config.treeViewElement = $('#workingfield');
        config.treeUrl = config.rootElement.data('url-tree');
    }

    Api.prototype = {
        constructor: Api,

        getTreeData: function (id, callBack) {
            if (typeof id !== 'string') {
                console.log('Id should be a string - ', id);
            }

            var url = id ?
                this.config.treeUrl + '?base=' + id :
                this.config.treeUrl;

            $.ajax({
                type: "GET",
                url: url,
                success: function (data) {
                    if (typeof data === 'string') {
                        JSON.parse(data);
                    } else if (typeof data === 'object') {
                        data = data
                    } else {
                        console.warn("Data has unusable format - ", typeof data);
                        return;
                    }

                    if (data && data.tree && data.tree.subtreez) {
                        data.tree.subtree = data.tree.subtree.sort(function (prev, next) {
                            return prev.id > next.id ? 1 : -1
                        })

                        data.tree.subtree.forEach(function (tree) {
                            tree.subtree = tree.subtree.sort(function (prev, next) {
                                return prev.id > next.id ? 1 : -1
                            })
                        });
                    }

                    if (typeof callBack === 'function') {
                        callBack(data);
                    }
                },
                error: function (error) {
                    console.warn('Request faild - ', error);
                }
            });
        },

        updateViewTree: function (id, isBranch) {
            var _this = this;

            var url = isBranch ?
                '/searchby?ldapsearch_scope=sub&ldapsearch_base=' + id :
                '/searchby?ldapsearch_scope=base&ldapsearch_base=' + id

            $.ajax({
                url: url,
		// function handleResponce is defined in umi-core-ajax.js
                success: handleResponce
            });
        }
    }

    return new Api;
})();
