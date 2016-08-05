# =require ./association

# CollectionAssociation is an abstract class that provides common stuff to ease the implementation
# of association proxies that represent collections.
class ActiveResource::Associations::CollectionAssociation extends ActiveResource::Associations::Association
  # @note Adds @queryName so it can be used in CollectionProxy when making Relations
  #
  # @param [ActiveResource::Base] the resource that owners this association
  # @param [ActiveResource::Reflection] reflection the reflection of the association
  constructor: (@owner, @reflection) ->
    @queryName = @klass().queryName
    super

  # Getter for the proxy to the target
  reader: ->
    @proxy ||= new ActiveResource::Associations::CollectionProxy(this)

  # Setter for the target
  #
  # @param [Collection,Array] resources the resources to assign to the association
  # @param [Boolean] save whether or not to persist the assignment on the server before
  #   continuing with the local assignment
  # @return [Promise] a promise that indicates that the assignment was successful **or** errors
  writer: (resources, save = true) ->
    resources = ActiveResource::Collection.build(resources)

    resources.each (r) => @__raiseOnTypeMismatch(r)

    persistAssignment =
      if save && !@owner.newresource?()
        @__persistAssignment(resources.select((r) -> r.persisted?()).toArray())
      else
        $.when(resources)

    _this = this
    persistAssignment
    .then ->
      _this.loaded(true) if save
      _this.replace(resources)

  # Pushes resources onto the target
  #
  # @param [Collection,Array] resources the resources to push onto the association
  # @return [Promise] a promise that indicates that the concat was successful **or** errors
  concat: (resources) ->
    resources = ActiveResource::Collection.build(resources)
    resources.each (r) => @__raiseOnTypeMismatch(r)

    persistConcat =
      if !@owner.newresource?()
        # TODO: Do something better with unpersisted resources, like saving them
        @__persistConcat(resources.select((r) -> r.persisted?()).toArray())
      else
        $.when(resources)

    _this = this
    persistConcat
    .then ->
      _this.__concatresources(resources)

  # Deletes resources from the target
  #
  # @param [Collection,Array] resources the resources to delete from the association
  # @return [Promise] a promise that indicates that the delete was successful **or** errors
  delete: (resources) ->
    resources = ActiveResource::Collection.build(resources)
    resources.each (r) => @__raiseOnTypeMismatch(r)

    persistDelete =
      if !@owner.newresource?()
        @__persistDelete(resources.select((r) -> r.persisted?()).toArray())
      else
        $.when(resources)

    _this = this
    persistDelete
    .then ->
      _this.__removeresources(resources)

  reset: ->
    super
    @target = ActiveResource::Collection.build()

  # Adds the resource to the target
  #
  # @note Uses `replaceOnTarget` to replace the resource in the target if it is
  #   already in the target
  #
  # @param [ActiveResource::Base] resource the resource to add to the target
  addToTarget: (resource) ->
    index = _.indexOf(@target.toArray(), resource)
    index = null if index < 0
    @replaceOnTarget(resource, index)

  # Pushs the resource onto the target or replaces it if there is an index
  #
  # @param [ActiveResource::Base] resource the resource to add to/replace on the target
  # @param [Integer] index the index of the existing resource to replace
  replaceOnTarget: (resource, index) ->
    if index?
      @target.set(index, resource)
    else
      @target.push resource

    @setInverseInstance(resource)
    resource

  # Checks whether or not the target is empty
  #
  # @note Does not take into consideration that the target may not be loaded,
  #   so if you want to truly know if the association is empty, check that
  #   `association(...).loaded() and association(...).empty()`
  #
  # @return [Boolean] whether or not the target is empty
  empty: ->
    @target.empty()

  # Builds resource(s) for the association
  #
  # @param [Object,Array<Object>] attributes the attributes to build into the resource
  # @return [ActiveResource::Base] the built resource(s) for the association, with attributes
  build: (attributes = {}) ->
    if _.isArray(attributes)
      _.map attributes, (attr) => @build(attr)
    else
      @__concatresources(ActiveResource::Collection.build(@__buildresource(attributes))).first()

  # Creates resource(s) for the association
  #
  # @note JSON API does not support creating multiple resources at once right now, so the
  #   callback will be called individually for each resource that is attempted to be created
  #
  # @param [Object,Array<Object>] attributes the attributes to build into the resource
  # @param [Function] callback the function to pass the built resource into after calling create
  #   @note May not be persisted, in which case `resource.errors().empty? == false`
  # @return [ActiveResource::Base] a promise to return the persisted resource(s) **or** errors
  create: (attributes = {}, callback) ->
    @__createresource(attributes, callback)

  # private

  __findTarget: ->
    _this = this
    ActiveResource.interface.get @links()['related']
    .then (resources) ->
      resources.each (r) -> _this.setInverseInstance(r)
      resources

  # Replaces the target with `other`
  #
  # @param [Collection] other the array to replace on the target
  replace: (other) ->
    @__removeresources(@target)
    @__concatresources(other)

  # Concats resources onto the target
  #
  # @param [Collection] resources the resources to concat onto the target
  __concatresources: (resources) ->
    resources.each (resource) =>
      @addToTarget(resource)
      @insertresource(resource)
    resources

  # Removes the resources from the target
  #
  # @note Only calls @__deleteresources for now, but can implement callbacks when
  #   the library gets to that point
  #
  # @param [Collection] the resources to remove from the association
  __removeresources: (resources) ->
    @__deleteresources(resources)

  # Deletes the resources from the target
  # @note Expected to be defined by descendants
  #
  # @param [Collection] resources the resource to delete from the association
  __deleteresources: (resources) ->
    throw '__deleteresources not implemented on CollectionAssociation'

  # Persists the new association by patching the owner's relationship endpoint
  #
  # @param [Array] resources the resource to delete from the association
  __persistAssignment: (resources) ->
    ActiveResource.interface.patch @links()['self'], resources, onlyResourceIdentifiers: true

  # Persists a concat to the association by posting to the owner's relationship endpoint
  #
  # @param [Array] resources the resource to delete from the association
  __persistConcat: (resources) ->
    ActiveResource.interface.post @links()['self'], resources, onlyResourceIdentifiers: true

  # Persists deleting resources from the association by deleting it on the owner's relationship endpoint
  #
  # @param [Array] resources the resource to delete from the association
  __persistDelete: (resources) ->
    ActiveResource.interface.delete @links()['self'], resources, onlyResourceIdentifiers: true

  # @see #create
  __createresource: (attributes, callback) ->
    throw 'You cannot call create unless the parent is saved' unless @owner.persisted?()

    if _.isArray(attributes)
      _.map attributes, (attr) => @__createresource(attr, callback)
    else
      resources = @__concatresources(ActiveResource::Collection.build(@__buildresource(attributes)))

      resources.each (resource) =>
        resource.save(callback)