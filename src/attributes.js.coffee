# =require ./global

# ActiveResource methods for managing attributes of resources
class ActiveResource::Attributes
  # Checks if the resource has an attribute
  #
  # @param [String] attribute the attribute to check the existence of on the resource
  # @return [Boolean] whether or not the resource has the attribute
  @hasAttribute: (attribute) ->
    @__readAttribute(attribute)?

  # Assigns `attributes` to the resource
  #
  # @param [Object] attributes the attributes to assign
  @assignAttributes: (attributes) ->
    for k, v of attributes
      try
        if @association(k).reflection.collection?()
          @[k]().assign(v, false)
        else
          @["assign#{s.capitalize(k)}"](v)
      catch
        @[k] = v

    null

  # Retrieves all the attributes of the resource
  #
  # @note A property is valid to be in `attributes` if it meets these conditions:
  #   1. It must not be a function
  #   2. It must not be a reserved keyword
  #   3. It must not be an association
  #
  # @return [Object] the attributes of the resource
  @attributes: ->
    reserved = ['__associations', '__errors', '__links', '__queryOptions']

    validOutput = (k, v) ->
      !_.isFunction(v) && !_.contains(reserved, k) &&
      try !@association(k)? catch e then true

    output = {}

    for k, v of @
      if validOutput(k, v)
        output[k] = v

    output

  # Reloads all the attributes from the server, using saved @__queryOptions
  # to ensure proper field and include reloading
  #
  # @example
  #   Order.includes('transactions').last().then (order) ->
  #     order.transactions.last().amount == 3.0 # TRUE
  #
  #     Transaction.find(order.transactions.last().id).then (transaction) ->
  #       transaction.update amount: 5, ->
  #         order.transactions.last().amount == 3.0 # TRUE
  #         order.reload().then ->
  #           order.transactions.last().amount == 5.0 # TRUE
  #
  # @return [Promise] a promise to return the reloaded ActiveResource **or** 404 NOT FOUND
  @reload: ->
    throw 'Cannot reload a resource that is not persisted' unless @persisted()

    resource = this
    ActiveResource.interface.get @links()['self'], @__queryOptions
    .then (reloaded) ->
      resource.assignAttributes(reloaded)

  # private

  # Reads an attribute on the resource
  #
  # @param [String] attribute the attribute to read
  # @return [Object] the attribute
  @__readAttribute: (attribute) ->
    @attributes()[attribute]