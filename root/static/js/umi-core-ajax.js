/*! 
 * NProgress indicator
 */

var sec = new Date().getTime() / 1000;

$(document).bind("ajaxSend", function(){
  
  console.log('UMI CORE AJAX: START ' + sec + ' ms');
  // console.time('UMI CORE AJAX: FINISH [' + sec + ']');
  NProgress.start();

}).bind("ajaxComplete", function(){

  NProgress.done();

  /* done in lib/UMI/HTML/FormHandler/Widget/Wrapper/Bootstrap4.pm
     $('.has-error').addClass('is-invalid');
     $('.has-error').next('.help-block').addClass('text-danger');
  */

  $("#stat-to").html('');
  $("#stat-from").appendTo("#stat-to");

  // console.timeEnd('UMI CORE AJAX: FINISH [' + sec + ']');
  console.log('UMI CORE AJAX: FINISH ' + sec + ' ms');
});

/*! 
 * AJAX to render any change 
 * IMPORTANT: https://api.jquery.com/serialize/
 *            Only "successful controls" are serialized to the string.
 *            No submit button value is serialized since the form was not submitted using a button.
 */

var handleResponce = function(html) {

  console.log('UMI CORE AJAX: RESPONSE handleResponce()',html);

  if( $(html).find("#form-signin").length ) {
    console.log('UMI CORE AJAX: is signin? '+$(html).find("#form-signin").length);
    location.href="/signin";
    return;
  }

  $('main').scrollTop(0);
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
$('#sidebar-left,#workingfield,#header,#sidebar-modal-1').on('click', 'a:not([href^="#"],[href="/"],.ajaxless)', function(e) {
  e.preventDefault();

  var a = this;
  var href = a.getAttribute('href');

  console.log('UMI CORE AJAX: ONCLICK ' + href);

  $('#modal-is-accounts').modal('hide');
  
  $.get(href, handleResponce );
});


/*! 
 * AJAX to load from the search form in the nav header
 * with element passing ldapbase_ dependent logic
 */    
$('form.formajaxer').on('submit', function(e) {
  e.preventDefault();

  var d = this;
  
  console.log('UMI CORE AJAX: ONSUBMIT attributes: ' + d.getAttributes);

  var base = '';
  var baseCaseVal = $('#ldap_base_case').val();
  if (baseCaseVal) {
    base = baseCaseVal.indexOf('=') > 0
      ? `&ldapsearch_base=${baseCaseVal}`
      : `&${baseCaseVal}=1`;
  }

  console.log('UMI CORE AJAX: ONSUBMIT base: ' + base);
  $.post($(this).attr('action'), $(this).serialize() + base, handleResponce);
});

// console.log('UMI CORE AJAX: ', $('form.settings-save'));
/*! 
 * AJAX to process settings saving form
 */    
$('#settings-save').on('submit', function(e) {
  e.preventDefault();
  console.log('UMI CORE AJAX: ONSUBMIT settings');
  $.post($(this).attr('action'), $(this).serialize(), function() {
    // Done is here
  });
});
