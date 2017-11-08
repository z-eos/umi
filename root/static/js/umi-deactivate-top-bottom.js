/*
 * Amaiak Abramian on 20151217
 */

// ;(function () {
//     var $topGroup     = $('.deactivate-top');
//     var $mixedGroup   = $('.deactivate-mixed');
//     var $bottomGroup  = $('.deactivate-bottom');
//     var $topInputs    = $('.deactivate-top').find('input');
//     var $mixedInputs  = $('.deactivate-mixed').find('input');
//     var $bottomInputs = $('.deactivate-bottom').find('input');

//     var $group        = $topGroup.add( $bottomGroup ).add( $mixedGroup );
//     var $inputs       = $group.find('input');
//     var $form         = $inputs.closest('form');

//     function checkFilder (element) {
//         var checkbox = element.type === 'checkbox' && element.checked;
//         var input    = element.type !== 'checkbox' && element.value !== "";

//         return checkbox || input;
//     };    

//     function checkFilderGroup($element) {
//         var condition = false;

//         $element.each(function () {
//             if ( checkFilder(this) ) {      
//                 condition = true;
//                 return false;
//             }
//         });

//         return condition;
//     };

//     function checkForm () {
//         var conditionTop    = checkFilderGroup( $topInputs );
//         var conditionMixed  = checkFilderGroup( $mixedInputs );
//         var conditionBottom = checkFilderGroup( $bottomInputs );

// 	// deactivate these if bottom active
//         $topInputs.prop('disabled', conditionBottom);
//         $mixedInputs.prop('disabled', conditionBottom);
	
//         // $topInputs.prop('disabled', conditionMixed);
	
//         $bottomInputs.prop('disabled', conditionMixed);
	
//         $bottomInputs.prop('disabled', conditionTop);
//         $mixedInputs.prop('disabled', conditionTop);
//     };

//     checkForm();

//     $form.on('change input', checkForm);
// })();


var currentMode = null;

/* desirable form modes (one elements disabled by others) */
function setMode(mode) {
    if (currentMode == mode) return;

    currentMode = mode;
    adaptInputs();
}

/* the very change-maker
 * 1. for all elements remove disabled state
 * 2. set disabled state for elements toggled by disabler element */
function adaptInputs() {
    $('.disableable').prop('disabled', false);
    if (currentMode) {
        $('.disabled-if-' + currentMode).prop('disabled', true);
    }
}

/* element disabler `checkbox' event */
$('.disabler-checkbox').on('change', function() {
    if ($(this).prop('checked')) {
        setMode($(this).data('mode'));
    } else {
        setMode(null);
    }
}).prop('checked', false);

/* element disabler `input' event */
$('.disabler-input').on('input', function() {
    if ($(this).val().length) {
	if ( currentMode === null ) {
            setMode($(this).data('mode'));
	}
    } else {
	if ( currentMode === $(this).data('mode') ) {
            setMode(null);
	}
    }
});
