/* --- SIMPLIFIED FORM SWITCHER start ----------------------------------------

  "simplified" user account creation switch. When checked, this
  checkbox causes all the service related UI been hidden and Domain
  Name field been unhided in the section "Person".

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

// --- FORM LOGICS start -----------------------------------------------------

$(function(){
    
    // --- !!! STUB !!! -----------------------------------------------------------
    // need this because HFH adds .has-error to whole hierarchy of objects
    // instead of the only fields error have been set
    // ----------------------------------------------------------------------------
    $(".duplicate").children(".form-group.has-error").removeClass("has-error");
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
	// UN HIDDING
	// each element with class of select data-name value will be un hidden
	currentRelation = false,
	selectServiceAuthQuery = "select[data-name='hwtype'], select[data-name='common_hwtype']",
	reinitRelations = function() {
	    $(selectServiceAuthQuery).each(function(id, select){
		var $select = $(select),
		    $option = $select.find("option:selected"),
		    relation = $option.data("relation");
		
		if (!relation || !relation.length) return;
		$select.parents(".hfh.repinst.form-group").find(".form-group.relation."+relation).removeClass("hidden");
	    });
	    

	},
	switchRelations = function(obj, newRelation) {
	    var $formGroupsRelated = $(".form-group.relation", obj).addClass("hidden");
	    
	    if (newRelation)
		$formGroupsRelated.each(function(id, element) {
		    var $el = $(element);
		    if ($el.hasClass(newRelation)) {
			$el.toggleClass("hidden");
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
		prefix = $option.data("relation-prefix"),
		relation = $option.data("relation"),
		value = $this.val();
	    
	    switchRelations(
		$this.parents(prefix && prefix.length ? "form" : ".hfh.repinst.form-group"),
		!relation || !relation.length || !value.length
		    ? false
		    : (prefix && prefix.length) ? prefix + relation : relation
	    );
	},
	serviceSelectAttachEvent = function($parent) {
	    $( $parent).on("change", selectServiceAuthQuery, onServiceChange);
	};
    
    serviceSelectAttachEvent($(document));
    reinitRelations();
});

// --- FORM LOGICS stop ------------------------------------------------------
