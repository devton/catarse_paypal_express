CATARSE.PayPalForm = CATARSE.UserDocument.extend({
  el: '#catarse_paypal_express_form',

  events: {
    'click input[type=submit]': 'onSubmitToPayPal',
    'keyup #user_document' : 'onUserDocumentKeyup'
  },

  initialize: function() {
    this.loader = $('.loader');
  },

  onSubmitToPayPal: function(e) {
    $(e.currentTarget).hide();
    this.loader.show();
  }
});
