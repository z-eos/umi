// define the tree-item component
Vue.component('ipam-tree-item', {
    template: '#ipam-template',
    props: {
	ipaitem: Object,
	faddr: Object
    },
    data: function () {
	return { isOpen: this.ipaitem && this.ipaitem.isOpen,
	         isOpenFaddr: false }
    },
    computed: {
	isIpaFolder: function () {
	    return this.ipaitem && this.ipaitem.children && this.ipaitem.children.length
	}
    },
    methods: {
	toggleIpaItem: function () {
	    if (this.isIpaFolder) {
		this.ipaitem.isOpen = !this.ipaitem.isOpen
	    }
	},
	setIpaState: function (branch, isOpen) {
	    var self = this;
	    if ( branch.children ) {
		branch.isOpen = isOpen;
		branch.children.forEach( function(ipaitem) {self.setIpaState(ipaitem, isOpen)} )
	    }
	},
	toggleIpaTree: function () {
	    //debugger;
	    if (this.isIpaFolder) {
		this.setIpaState(this.ipaitem, !this.ipaitem.isOpen)
	    }
	},
	makeIpaFolder: function () {
	    if (!this.isIpaFolder) {
      		this.$emit('make-folder', this.ipaitem)
		this.isOpen = true
	    }
	},
	showIpaItem: function (scope) {
	    // console.log(this.ipaitem.dn);
	    var url;
	    var re    = /^(?!0)(?!.*\.$)((1?\d?\d|25[0-5]|2[0-4]\d)(\.|$)){3}$/;
	    var _this = this;
	    var ip; 
	    if ( !re.test(this.ipaitem.dn) || (re.test(this.ipaitem.dn) && scope) ) {
		re = /^(?!0)(?!.*\.$)((1?\d?\d|25[0-5]|2[0-4]\d)(\.|$)){4}$/;
		if ( re.test(this.ipaitem.dn) ) {
		    url =
			'/searchby?ldapsearch_filter=|'  +
			'(dhcpStatements=fixed-address ' + this.ipaitem.dn + ')'  +
			'(umiOvpnCfgIfconfigPush='       + this.ipaitem.dn + '*)' +
			'(umiOvpnCfgIroute='             + this.ipaitem.dn + '*)' +
			'(ipHostNumber='                 + this.ipaitem.dn + ')'  +
			'&ldapsearch_scope=sub';
		    console.log('re match: url: '+url)
		} else {
		    url =
			'/searchby?ldapsearch_filter=|'  +
			'(dhcpStatements=fixed-address ' + this.ipaitem.dn + '*)' +
			'(umiOvpnCfgIfconfigPush='       + this.ipaitem.dn + '*)' +
			'(umiOvpnCfgIroute='             + this.ipaitem.dn + '*)' +
			'(ipHostNumber='                 + this.ipaitem.dn + '*)' +
			'&ldapsearch_scope=sub';
		    console.log('re not match: url: '+url)
		}
		$.ajax({
		    url: url,
		    success: function (html) {
			$('#workingfield').html(html);
			handleResponce();
		    }
		});
	    } else {
		url = '/ldap_tree/ipa?naddr=' + this.ipaitem.dn;
		$.ajax({
		    url: url,
		    success: function(faddr) {
			if (typeof faddr === 'string') {
			    // console.log('faddr is string')
			    faddr = JSON.parse(faddr)
			} else if (typeof faddr === 'object') {
			    // console.log('faddr is object')
			    faddr = faddr.json_tree
			} else {
			    console.warn("Data has unusable format - ", typeof faddr)
			    return
			}
			sortIpaRecursively(faddr);
			_this.faddr = faddr;
			// console.log(faddr)
		    }
		});
	    }
	},
	resolveThis: function () {
	    var item = this.ipaitem;
	    // console.log(item.isOpen);
	    if ( item.host || item.dn.split(".").length < 4 ) {
		return;
	    }
	    var url = '/resolve_this?ptr=' + item.dn;
	    $.ajax({
		url: url,
		success: function (host) {
		    // if ( host.indexOf('<') == -1) {
		    // 	item.host = host;
		    // } else {
		    // 	item.host = 'NXDOMAIN';
		    // }
		    item.host = host;
		    // console.log(host);
		}
	    });
	    // console.log('showItem scope:', scope);
	}
    }
});


// boot up
var ipamTree = new Vue({
    el: '#ipam-tree',

    data: function () {
        return { ipamtree: {},
		 loading: true }
    },
    
    mounted: function () {
        this.getIpaTreeData();
    },

    methods: {
	makeIpaFolder: function (ipaitem) {
    	    Vue.set(ipaitem, 'children', [])
	},
	
	getIpaTreeData:  function () {
	    var _this = this;
	    _this.loading = true;
	    $.ajax({
		type: "GET",
		url: '/ldap_tree/ipa',
		success: function (data) {
		    if (typeof data === 'string') {
			// console.log('data is string')
			data = JSON.parse(data)
		    } else if (typeof data === 'object') {
			// console.log('data is object')
			data = data.json_tree
		    } else {
			console.warn("Data has unusable format - ", typeof data)
			return
		    }
		    sortIpaRecursively(data);	
		    _this.ipamtree = data;
		    _this.hover = false;
		    _this.loading = false;
		    // console.log(_this.ipamtree)
		},
		error: function (error) {
		    console.warn('Request faild - ', error)
		}
	    });	
	},

    }
});

function inet_aton(ip){
    // split into octets
    var a = ip.split('.');
    var buffer = new ArrayBuffer(4);
    var dv = new DataView(buffer);
    for(var i = 0; i < 4; i++){
        dv.setUint8(i, a[i]);
    }
    return(dv.getUint32(0));
}

const compareIpaFunc = (a, b) => {
    const aVal = a.name.toLowerCase();
    const bVal = b.name.toLowerCase();
    if (aVal === bVal) return 0;
    return inet_aton(aVal) > inet_aton(bVal) ? 1 : -1;
};

const sortIpaRecursively = arr => {
    if (arr.children) {
      arr.children = arr.children.map(sortIpaRecursively).sort(compareIpaFunc);
    }
    return arr;
};

// function for copying selected text in clipboard
function copyText() {
    selectText();

    $('#ip-copied').html(event.target.innerText)
    $('#ip-copied-toast').toast('show')
    // $(event.target).popover({ container: $(event.target).parent(),
    // 			      content: event.target.innerText + ' copied to clipboard' })
    
    //alert(event.target.innerText + ' copied to clipboard')
    document.execCommand("copy");
}

function selectText() {
    var element = event.target
    var range;
    if (document.selection) {
        // IE
        range = document.body.createTextRange();
        range.moveToElementText(element);
        range.select();
    } else if (window.getSelection) {
        range = document.createRange();
        range.selectNode(element);
        window.getSelection().removeAllRanges();
        window.getSelection().addRange(range);
    }
}
