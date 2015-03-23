$(function(){

    // --- !!! STUB !!! -----------------------------------------------------------
    // need this because HFH adds .has-error to whole hierarchy of objects
    // instead of the only fields error have been set
    // ----------------------------------------------------------------------------
    $(".duplicate").children(".form-group.has-error").removeClass("has-error");
    $(".form-group.hfh-repinst.has-error").removeClass("has-error");
    $(".no-has-error.has-error").removeClass("has-error");
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
	    $(selectServiceAuthQuery, $parent).on("change", onServiceChange);
	},
	duplicatedAttachEvent = function($parent, unhide) {
	    var $rmDuplicate = $parent
		.find(".rm-duplicate");
	    $rmDuplicate
		.click(function(){
		    $(this).parents(".duplicated").remove();
		});
	    if (unhide) {
		$rmDuplicate.removeClass("hidden");
	    } else {
		$(".duplicated .rm-duplicate", $parent).removeClass("hidden");
	    }
	};
    
    // duplicating code
    // $("a span.rm-duplicate").on("click",function(e){
    $("a.btn[data-duplicate]").on("click",function(e){
	e.preventDefault();
	var $a = $(this),
            counter = parseInt($a.data("counter")) || ($a.data("counter",0),0),
            $fieldset = $a.parents("fieldset"),
            $duplicateOriginal = $fieldset.find("div."+$a.data('duplicate')),
	    $duplicate = $duplicateOriginal.first().clone(),
	    $parent = $duplicateOriginal.parent();
	++counter;
	
	$duplicate
	    .removeAttr("id")
	    .removeClass("duplicate")
	    .addClass("duplicated")
	    .children()
	    .prop("id",$duplicateOriginal.parents(".form-group").attr("id")+"."+counter);

	$("input:text, input:password, input:file, select, textarea, input:radio, input:checkbox", $duplicate).each(function(id, element){
	    var $element = $(element),
		name = $element.data("group")+"."+counter+"."+$element.data('name');
	    $element
		.removeAttr("id")
		.prop("name", name);
	    resetElement($element);
	    
	    var $formGroups = $element.parents(".form-group");
	    $formGroups.each(function(index, formGroupElement){
		var $formGroup = $(formGroupElement);
		if ($formGroup.hasClass("relation")) $formGroup.addClass("hidden");
		$formGroup
		    .find("label")
		    .prop("for", name);	
	    });
	});
	
	$duplicate.appendTo($parent);
	// $duplicate.find(".fa-times-circle").removeClass("hidden").click(function(){
	/*$duplicate.find(".rm-duplicate").removeClass("hidden").click(function(){
	  $(this).parents(".duplicated").remove();
	  });*/
	duplicatedAttachEvent($duplicate, !0);
	serviceSelectAttachEvent($duplicate);

	$('html, body').animate({
	    scrollTop: $duplicate.offset().top-80
	}, 1000);
	
	$a.data("counter",counter);   
    });

    serviceSelectAttachEvent($(document));
    duplicatedAttachEvent($(document));
});
