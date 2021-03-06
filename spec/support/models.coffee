# Imply that a singular version of the word 'Class' is still 'Class'
_.singular('Class', 'Class');

window.MyLibrary = ActiveResource.createResourceLibrary('https://example.com/api/v1')

class MyLibrary::Comment extends MyLibrary.Base
  this.className = 'Comment'
  this.queryName = 'comments'

  this.belongsTo 'resource', polymorphic: true

class MyLibrary::GiftCard extends MyLibrary.Base
  this.className = 'GiftCard'
  this.queryName = 'gift_cards'

  this.hasOne 'order'

class MyLibrary::Order extends MyLibrary.Base
  this.className = 'Order'
  this.queryName = 'orders'

  this.belongsTo 'giftCard'
  this.belongsTo 'product'

  this.hasMany 'comments', as: 'resource'
  this.hasMany 'orderItems'
  this.hasMany 'transactions', autosave: true

class MyLibrary::OrderItem extends MyLibrary.Base
  this.className = 'OrderItem'
  this.queryName = 'order_items'

  this.belongsTo 'order'

class MyLibrary::PaymentMethod extends MyLibrary.Base
  this.className = 'PaymentMethod'
  this.queryName = 'payment_methods'

  this.hasMany 'transactions'

class MyLibrary::Product extends MyLibrary.Base
  this.className = 'Product'
  this.queryName = 'products'

  this.hasMany 'orders'

class MyLibrary::Transaction extends MyLibrary.Base
  this.className = 'Transaction'
  this.queryName = 'transactions'

  this.belongsTo 'order'
  this.belongsTo 'paymentMethod'
