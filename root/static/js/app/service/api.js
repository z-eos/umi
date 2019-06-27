window.Service = window.Service || {};

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
            var url;

            if (typeof id !== 'string') {
                console.log('Id should be a string - ', id);
            }
            
            if ( id ) {
                url = '/ldap_tree?base=' + id;
            } else {
                url = '/ldap_tree';
            }

            $.ajax({
                type: "GET",
                url: url,
                success: function (data) {
                    if (typeof data === 'string') {
                        JSON.parse(data);
                    } else if (typeof data === 'object') {
			/* here we expect array of hashes */
                        // data = data
                        data = data.json_tree
                    } else {
                        console.warn("Data has unusable format - ", typeof data);
                        return;
                    }

                    if (typeof callBack === 'function') {
                        callBack(data.sort(function (prev, next) {
                            prevId = prev.id.toLowerCase().split('=')[1].replace(/\W/ig, '');
                            nextId = next.id.toLowerCase().split('=')[1].replace(/\W/ig, '');
        
                            return nextId < prevId ? 1 : -1;
                        }));
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
                '/searchby?ldapsearch_scope=base&ldapsearch_base=' + id;

            $.ajax({
                url: url,
                success: function (html) {
                    _this.config.treeViewElement.html(html);
        		    handleResponce();
                }
            });
        }
    }

    return new Api;
})();
