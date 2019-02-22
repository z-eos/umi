/* --- SIMPLIFIED FORM SWITCHER start ----------------------------------------

  "simplified" user account creation switch. When checked, this checkbox causes all 
  the service related UI been hidden and Domain Name field been unhided in the section "Person".

*/
//if (!$(".has-error")) {
    $('.simplified').hide(300);
    $('#person_namesake').prop('checked', false);
    $('#person_simplified').prop('checked', false);
//}

$("#person_simplified").click(function() {
    if($(this).is(":checked")) {
	$('.simplified').show(300);
	$('.complex').hide(300);
    } else {
	$('.simplified').hide(300);
	$('.complex').show(300);
    }  
});
// --- SIMPLIFIED FORM SWITCHER stop -----------------------------------------

/* --- SSHPUBKEY/FILE SWITCHER start -----------------------------------------

   hide one of `sshpubkey' or `sshpubkeyfile' according the clicked
   one (if one clicked, another one is hidden)
*/
/*$('textarea[data-group=loginless_ssh]').on('input', function () {
    var $file = $(this).closest('.repinst').find('[id=sshpubkeyfile]');
	this.value === '' ? $file.show() : $file.hide();
});

var global = {};

global.triggerTextarea = function (self) {
	var $textarea = $(self).closest('.repinst').find('[id="sshpubkey"]');

	setTimeout(function () {
		self.files && self.files.length
			? $textarea.hide()
			: $textarea.show()
	}, 10);
};*/
// --- SSHPUBKEY/FILE SWITCHER stop ------------------------------------------

// --- RELATIONS LOGICS start -----------------------------------------------------

$(function(){
    
    // --- !!! STUB !!! -----------------------------------------------------------
    // need this because HFH adds .has-error to whole hierarchy of objects
    // instead of the only fields error have been set
    // ----------------------------------------------------------------------------
    $(".form-group.hfh-repinst.has-error").removeClass("has-error");
    $(".no-has-error.has-error").removeClass("has-error");
    $("#loginless_ovpn").removeClass("has-error");
    $("#loginless_ssh").removeClass("has-error");
    
    // ----------------------------------------------------------------------------

    
    // clean whole element (input:text, input:password, input:file, select, textarea, input:radio, input:checkbox) to default state
    var resetElement = function($element) {
	$element
            .val('')
            .removeAttr('checked')
            .removeAttr('selected')
            .children("option")
            .first()
            .prop("selected",true);
    },
	currentRelation = false,
	selectServiceAuthQuery = "select[data-name='authorizedservice']",
	reinitRelations = function() {
	    $(selectServiceAuthQuery).each(function(id, select){
		var $select = $(select),
		    $option = $select.find("option:selected"),
		    relation = $option.data("relation");
		
		if (!relation || !relation.length) return;
		$select.parents(".hfh.repinst.form-group").find(".form-group.relation."+relation).removeClass("d-none");
	    });
	    

	},
	switchRelations = function(obj, newRelation) {
	    var $formGroupsRelated = $(".form-group.relation", obj).addClass("d-none");
	    
	    if (newRelation)
		$formGroupsRelated.each(function(id, element) {
		    var $el = $(element);
		    if ($el.hasClass(newRelation)) {
			$el.toggleClass("d-none");
			$("input:text, input:password, input:file, select, textarea, input:radio, input:checkbox", $el).each(function(index, item){
			    resetElement($(item));
			});
		    }
		});
	    
	    currentRelation = newRelation;
	},
	onServiceChange = function(event){
	    var $this = $(this),
		$option = $this.find("option:selected"),
		relation = $option.data("relation"),
		value = $this.val();
	    
	    switchRelations(
		$this.parents(".hfh.repinst.form-group"),
		!relation || !relation.length || !value.length
		    ? false
		    : relation
	    );
	},
	serviceSelectAttachEvent = function($parent) {
	    $( $parent ).on("change", selectServiceAuthQuery, onServiceChange);
	};    

    serviceSelectAttachEvent($(document));
    reinitRelations();
});

// --- RELATIONS LOGICS stop ------------------------------------------------------
