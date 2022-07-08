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
	    // if (message.error.html) 
	    // 	return $("<pre>").addClass("text-danger").html(message.error.0.html);
	    // if (message.warning.html) 
	    // 	return $("<pre>").addClass("text-warning").html(message.warning.0.html);
	    //var $modal = $(".modal.in[aria-hidden='false'] .modal-content");
	    //return ($modal.length) ? $modal.html(message) : alert(message);
	    // # # # return $(message);

	    //return $("<div>").addClass("text-danger").html(message);
	    return $("<div id=\"modal_delete_data\">").html(message);
	    // original // return $("<div>").addClass("text-danger").html(message);
	},

	applyError = function(item, message) {
	    // # # # item.parents(".modal-content").html(message);
	    // $("body").append(getErrorBlock(message));
	    // original // item.parents().prepend(getErrorBlock(message));
	    // item.closest('.modal-body').append(getErrorBlock(message));
	    // item.parent().prepend(getErrorBlock(message));
	  const errorContainer = item.closest('.modal-content').find(".modal-error");
	  if ( errorContainer.length ) {
	    errorContainer.html(message);
	  } else {
	    console.error('applyError: find returned zerro length; ' + message);
	  }
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
	    // if not exists then append
	    if (!$("input[type='hidden'][name='type']", $form).length) { 
		$form.append(hidden).append(type);
	    }
	    var data = $form.serialize();
	    var $tr = obj.parents("tr");
	    var action = obj.data("action");
	    var $modal = obj.parents(".modal");

	    //clearPopupForm($(".modal:not(.in)"));// REMOVE

	    $.ajax({
		type: "POST",
		url: $form.attr("action"),
		data: data,
		dataType: "json",
		success: function(data) {
		    if (!data || typeof data.success === "undefined") return applyError(obj, options.ajaxSystemError), false;
		    if (data && data.success == 0) return applyError(obj, data.message), false;
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
		    case "block":
			if ($modal && $modal.length) $modal.modal("hide");
			break;
		    case "reassign":
			if ($modal && $modal.length) $modal.modal("hide");
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

	    // console.log('GET LOGIC TYPE: ', getLogicType($this));
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
		// $('.modal-open').removeClass('modal-open');
		// $('.modal-backdrop').remove();
		break;
	    }
	    return false;
	};

    //clearPopupForm($(".modal:not(.in)")); // REMOVE

    $("body").on("click", options.btnEvent, onBtnEventClick);
});
