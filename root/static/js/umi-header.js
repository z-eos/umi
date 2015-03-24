$(function () {
    $('[data-toggle="tooltip"]').tooltip()
});


// navbar search field submit by key "enter" press
$( '.umi-navbar-menu-btn' ).click( function () {
    $('.navbar-form').submit();
});

$('[name=ldapsearch_filter]').on('keypress', function (event) {
    if ( event.which === 13 ) {
        $('[name=ldapsearch_by_name]').trigger('click');
    }
});

