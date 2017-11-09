/*! 
 * AJAX to render any change 
 */    
var handleResponce = function(html) {
    console.log('RESPONCE: handleResponce');
    NProgress.start();

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

	console.log('VERY AJAX: ' + $(this).attr('action') + ' ? ' + postData);
	$.ajax({
	    url: $(this).attr('action'),
	    data: postData,
	    processData: false,
	    contentType: contentType,
	    type: 'POST',
	    success: handleResponce,
	    error: handleResponce
	});
	
	// $.post($(this).attr('action'), postData, handleResponce);
    });
    NProgress.done();
};


/*! 
 * AJAX to load on click-s (not submits)
 */    
$('#sidebar,#workingfield,#header').on('click', 'a:not([href^="#"],[href="/"])', function(e) {
    e.preventDefault();

    NProgress.start();

    var a = this;
    var href = a.getAttribute('href');

    console.log('ONCLICK: ' + href);
    
    $.get(href, handleResponce );
});


/*! 
 * AJAX to load from header form (with element passing ldapbase_ dependent logic)
 */    
$('form.formajaxer').on('submit', function(e) {
    e.preventDefault();

    NProgress.start();

    var d = this;
    
    console.log('ONSUBMIT: attributes: ' + d.getAttributes);

    var base = $('#ldap_base_case').val().indexOf('=') > 0
	? '&ldapsearch_base=' + $('#ldap_base_case').val()
	: '&' + $('#ldap_base_case').val() + '=1';

    console.log('ONSUBMIT: base: ' + base);
    $.post($(this).attr('action'), $(this).serialize() + base, handleResponce);
});
