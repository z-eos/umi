$(function(){
    "use strict";

    var options = {
	btnEvent: ".umi-btn-event",
	btnEventLogic: ".umi-btn-logic",
	btnEventAjax: ".umi-btn-ajax",
	noActionEventMsg: "Cannot find action attribute for this button event!",
	noFormEventMsg: "Cannot find parent form for this button event!",
	noAjaxModeMsg: "Ajax mode not supported, yet...",
	ajaxError: "Error on request: ",
	ajaxSystemError: "Wrong response format from server!"
    },

	getErrorBlock = function(message) {
	    return $("<div>").addClass("text-danger").html(message);
	},

	applyError = function(item, message) {
	    item.parent().prepend(getErrorBlock(message));
	},

	createHiddenButton = function(item, value) {
	    var simple = (typeof value !== "undefined");
	    if (!simple) {
		var input = $(item).parents("form").find("input[name='"+item.attr("name")+"'][type='hidden']");
		if (input && input.length) {
		    return input.attr("value", item.val());
		}
	    }

	    return $("<input>")
		.attr("type","hidden")
		.attr("name", (simple) ? item : item.attr("name"))
		.attr("value", (simple) ? value : item.val());
	},

	getLogicType = function(obj) {
	    if (obj.hasClass(options.btnEventLogic.substr(1,options.btnEventLogic.length))) return "basic";
	    if (obj.hasClass(options.btnEventAjax.substr(1,options.btnEventAjax.length))) return "ajax";
	    return "close";
	},

	removeObjects = function(objects) {
	    if (!objects || !Array.isArray(objects) || !objects.length) return;
	    objects.forEach(function(object){
		object.remove();
	    });
	},

	runAjaxLogic = function(obj) {
	    var $form = obj.parents("form");
	    if (!$form || !$form.length) return applyError(obj, options.noFormEventMsg), false;
	    var hidden = createHiddenButton(obj);
	    var type = createHiddenButton("type", "json");
	    $form.append(hidden).append(type);
	    var data = $form.serialize();
	    var $tr = obj.parents("tr");
	    var action = obj.data("action");
	    var $modal = obj.parents(".modal.in");

	    //clearPopupForm($(".modal:not(.in)"));// REMOVE

	    $.ajax({
		type: "POST",
		url: $form.attr("action"),
		data: data,
		dataType: "json",
		success: function(data) {
		    if (!data || typeof data.success === "undefined") return applyError(obj, options.ajaxSystemError), false;
		    if (data && data.success === false) return applyError(obj, data.message), false;
		    switch(action) {
		    default:
		    case "delete":
			if ($modal && $modal.length) $modal.modal("hide");
			$
			    .when($tr.fadeOut("800"))
			    .then(function(){
				$tr.remove();
			    });
			break;
		    }
		    removeObjects([hidden, type]);
		},
		error: function(x, o, e){
		    applyError(obj, options.ajaxError+e+"<hr class='text-warning'>"+data);
		    removeObjects([hidden, type]);
		}
	    });
	},

	runBasicLogic = function(obj) {
	    var action = obj.data("umiact");
	    if (!action || !action.length) return applyError(obj, options.noActionEventMsg), false;
	    var $form = obj.parents("form");
	    if (!$form || !$form.length) return applyError(obj, options.noFormEventMsg), false;
	    var hidden = createHiddenButton(obj);
	    //clearPopupForm($(".modal:not(.in)")); // REMOVE
	    $form.append(hidden).attr("action", action).submit();

	},

	clearPopupForm = function($class) {
	    if (!($class instanceof Object)) $class=$($class);
	    $class.find("input[type='checkbox']").prop("checked", false);
	},

	onBtnEventClick = function(event) {
	    event.preventDefault();
	    var $this = $(this);

	    switch(getLogicType($this)) {
	    default:
	    case "close":
		clearPopupForm($this.parents(".modal"));
		break;
	    case "basic":
		runBasicLogic($this);
		break;
	    case "ajax":
		runAjaxLogic($this);
		break;
	    }
	    return false;
	};

    //clearPopupForm($(".modal:not(.in)")); // REMOVE

    $("body").on("click", options.btnEvent, onBtnEventClick);
});
