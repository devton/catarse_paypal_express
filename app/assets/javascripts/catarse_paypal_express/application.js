$(function(){
  $('#catarse_paypal_express_form form').change(function(event){
    if($('#catarse_paypal_express_form form input#accept:checked').length > 0) {
      $('input[type=submit]', $(event.currentTarget)).attr('disabled', false);
    } else {
      $('input[type=submit]', $(event.currentTarget)).attr('disabled', true);
    }
  });
});
