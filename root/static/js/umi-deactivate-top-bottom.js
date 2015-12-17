;(function () {
    var $topGroup     = $('.deactivate-top');
    var $bottomGroup  = $('.deactivate-bottom');
    var $topInputs    = $('.deactivate-top').find('input');
    var $bottomInputs = $('.deactivate-bottom').find('input');

    var $group        = $topGroup.add( $bottomGroup );
    var $inputs       = $group.find('input');
    var $form         = $inputs.closest('form');


    function checkFilder (element) {
        var checkbox = element.type === 'checkbox' && element.checked;
        var input    = element.type !== 'checkbox' && element.value !== "";

        return checkbox || input;
    };
    

    function checkFilderGroup($element) {
        var condition = false;

        $element.each(function () {
            if ( checkFilder(this) ) {      
                condition = true;
                return false;
            }
        });

        return condition;
    };


    function checkForm () {
        var conditionTop        = checkFilderGroup( $topInputs );
        var conditionBottom = checkFilderGroup( $bottomInputs );

        $topInputs.prop('disabled', conditionBottom);
        $bottomInputs.prop('disabled', conditionTop);
    };

    checkForm();

    $form.on('change input', checkForm);

})();
