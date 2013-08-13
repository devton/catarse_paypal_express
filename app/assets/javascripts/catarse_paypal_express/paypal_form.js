App.addChild('PayPalForm', _.extend({
  el: '#catarse_paypal_express_form',

  events: {
    'click input[type=submit]': 'onSubmitToPayPal',
    'keyup #user_document' : 'onUserDocumentKeyup'
  },

  activate: function() {
    this.loader = $('.loader');
    this.parent.backerId = $('input#backer_id').val();
    this.parent.projectId = $('input#project_id').val();
  },

  onSubmitToPayPal: function(e) {
    $(e.currentTarget).hide();
    this.loader.show();
  }
}, window.PayPal.UserDocument));
