$(function(){
  $('#catarse_paypal_express_form input[type=submit]').click(function(){
    $(this).hide();
    $('#catarse_paypal_express_form .loader').show();
  });
});
