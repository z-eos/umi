;(function () {

    var $divFile = $('#fieldfile');
    var $divLdif = $('#fieldldif');
    
    var $elementFile = $('#file');
    var $elementLdif = $('#ldif');

    var $reset = $('#aux_reset')
    
    if ( !$elementFile.length || !$elementLdif.length ) return;


    function checkValues () {

	if ( $elementFile[0].files.length ) {
            $divLdif.hide();
	} else {
            $divLdif.show();
	};

	if ( $elementLdif[0].value === '' ) {
            $divFile.show();
	} else {
            $divFile.hide();
	};

    };

    $elementFile.closest('form').on('reset', function () {
	setTimeout(function () { checkValues() }, 10);
    });
    
    $elementFile.on('change', checkValues);
    $elementLdif.on('input', checkValues);

})();
