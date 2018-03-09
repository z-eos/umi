/*! 
 * NProgress indicator
 */

$(document).bind("ajaxSend", function(){

    console.log('UMI CORE AJAX: START');    
    NProgress.start();

}).bind("ajaxComplete", function(){

    NProgress.done();
    console.log('UMI CORE AJAX: FINISH ');    

    $("#stat-to").html('');
    $("#stat-from").appendTo("#stat-to");

});

/*! 
 * AJAX to render any change 
 * IMPORTANT: https://api.jquery.com/serialize/
 *            Only "successful controls" are serialized to the string.
 *            No submit button value is serialized since the form was not submitted using a button.
 */

var handleResponce = function(html) {

    console.log('UMI CORE AJAX: RESPONCE handleResponce');

    $('#workingfield').html(html);
    
    $('#workingfield form.formajaxer').on('submit', function(e) {
	e.preventDefault();

	var postData;
	var contentType;
	var files = $(this).find('[type=file]');
	if ( files.length ) {
	    contentType = false; //'multipart/form-data';
	    postData = new FormData(this);
	} else {
	    contentType = 'application/x-www-form-urlencoded';
	    postData = $(this).serialize();
	}

	console.log('UMI CORE AJAX: ACTION ' + $(this).attr('action') + ' ? ' + postData);
	$.ajax({
	    url: $(this).attr('action'),
	    data: postData,
	    processData: false,
	    contentType: contentType,
	    type: 'POST',
	    success: handleResponce,
	    error: function(xhr) { console.log('ERROR',arguments); handleResponce(xhr.responseText) }
	});
	
	// $.post($(this).attr('action'), postData, handleResponce);
    });

    $(".app-body, body, html").scrollTop(0);
};

/*! 
 * AJAX to load on click-s (not submits)
 */    
$('#sidebar,#workingfield,#header').on('click', 'a:not([href^="#"],[href="/"],.ajaxless)', function(e) {
    e.preventDefault();

    var a = this;
    var href = a.getAttribute('href');

    console.log('UMI CORE AJAX: ONCLICK ' + href);
    
    $.get(href, handleResponce );
});


/*! 
 * AJAX to load from header form (with element passing ldapbase_ dependent logic)
 */    
$('form.formajaxer').on('submit', function(e) {
    e.preventDefault();

    var d = this;
    
    console.log('UMI CORE AJAX: ONSUBMIT attributes: ' + d.getAttributes);

    var base = $('#ldap_base_case').val().indexOf('=') > 0
	? '&ldapsearch_base=' + $('#ldap_base_case').val()
	: '&' + $('#ldap_base_case').val() + '=1';

    console.log('UMI CORE AJAX: ONSUBMIT base: ' + base);
    $.post($(this).attr('action'), $(this).serialize() + base, handleResponce);
});
