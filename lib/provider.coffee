fs = require 'fs'
path = require 'path'

trailingWhitespace = /\s$/
attributePattern = /\s+([a-zA-Z][-a-zA-Z]*)\s*=\s*$/
tagPattern = /<([a-zA-Z][-a-zA-Z]*)(?:\s|$)/

module.exports =
  selector: '.text.html'

  getSuggestions: (request) ->
    if @isAttributeValueStartWithNoPrefix(request)
      @getAllAttributeValueCompletions(request)
    else if @isAttributeValueStartWithPrefix(request)
      @getAttributeValueCompletions(request)
    else if @isAttributeStartWithNoPrefix(request)
      @getAllAttributeNameCompletions(request)
    else if @isAttributeStartWithPrefix(request)
      @getAttributeNameCompletions(request)
    else if @isTagStartWithNoPrefix(request)
      @getAllTagNameCompletions()
    else if @isTagStartTagWithPrefix(request)
      @getTagNameCompletions(request)
    else
      []

  onDidInsertSuggestion: ({editor, suggestion}) ->
    setTimeout(@triggerAutocomplete.bind(this, editor), 1) if suggestion.type is 'attribute'

  triggerAutocomplete: (editor) ->
    atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:activate')

  isTagStartWithNoPrefix: ({prefix, scopeDescriptor}) ->
    scopes = scopeDescriptor.getScopesArray()
    prefix is '<' and scopes.length is 1 and scopes[0] is 'text.html.basic'

  isTagStartTagWithPrefix: ({prefix, scopeDescriptor}) ->
    return false unless prefix
    return false if trailingWhitespace.test(prefix)
    @hasTagScope(scopeDescriptor.getScopesArray())

  isAttributeStartWithNoPrefix: ({prefix, scopeDescriptor}) ->
    return false unless trailingWhitespace.test(prefix)
    @hasTagScope(scopeDescriptor.getScopesArray())

  isAttributeStartWithPrefix: ({prefix, scopeDescriptor}) ->
    return false unless prefix
    return false if trailingWhitespace.test(prefix)

    scopes = scopeDescriptor.getScopesArray()
    return true if scopes.indexOf('entity.other.attribute-name.html') isnt -1
    return false unless @hasTagScope(scopes)

    scopes.indexOf('punctuation.definition.tag.html') isnt -1 or
      scopes.indexOf('punctuation.definition.tag.end.html') isnt -1

  isAttributeValueStartWithNoPrefix: ({scopeDescriptor, prefix}) ->
    lastPrefixCharacter = prefix[prefix.length - 1]
    return false unless lastPrefixCharacter in ['"', "'"]
    scopes = scopeDescriptor.getScopesArray()
    @hasStringScope(scopes) and @hasTagScope(scopes)

  isAttributeValueStartWithPrefix: ({scopeDescriptor, prefix}) ->
    lastPrefixCharacter = prefix[prefix.length - 1]
    return false if lastPrefixCharacter in ['"', "'"]
    scopes = scopeDescriptor.getScopesArray()
    @hasStringScope(scopes) and @hasTagScope(scopes)

  hasTagScope: (scopes) ->
    scopes.indexOf('meta.tag.any.html') isnt -1 or
      scopes.indexOf('meta.tag.other.html') isnt -1 or
      scopes.indexOf('meta.tag.block.any.html') isnt -1 or
      scopes.indexOf('meta.tag.inline.any.html') isnt -1 or
      scopes.indexOf('meta.tag.structure.any.html') isnt -1

  hasStringScope: (scopes) ->
    scopes.indexOf('string.quoted.double.html') isnt -1 or
      scopes.indexOf('string.quoted.single.html') isnt -1

  getAllTagNameCompletions: ->
    completions = []
    for tag, attributes of @completions.tags
      completions.push({text: tag, type: 'tag'})
    completions

  getTagNameCompletions: ({prefix}) ->
    completions = []
    lowerCasePrefix = prefix.toLowerCase()
    for tag, attributes of @completions.tags when tag.indexOf(lowerCasePrefix) is 0
      completions.push({text: tag, type: 'tag'})
    completions

  getAllAttributeNameCompletions: ({editor, bufferPosition}) ->
    completions = []

    tag = @getPreviousTag(editor, bufferPosition)
    tagAttributes = @getTagAttributes(tag)
    for attribute in tagAttributes
      completions.push({snippet: "#{attribute}=\"$1\"$0", displayText: attribute, type: 'attribute', rightLabel: "<#{tag}>"})

    for attribute, options of @completions.attributes
      completions.push({snippet: "#{attribute}=\"$1\"$0", displayText: attribute, type: 'attribute'}) if options.global

    completions

  getAttributeNameCompletions: ({editor, bufferPosition, prefix}) ->
    completions = []
    lowerCasePrefix = prefix.toLowerCase()

    tag = @getPreviousTag(editor, bufferPosition)
    tagAttributes = @getTagAttributes(tag)
    for attribute in tagAttributes when attribute.indexOf(lowerCasePrefix) is 0
      completions.push({snippet: "#{attribute}=\"$1\"$0", displayText: attribute, type: 'attribute', rightLabel: "<#{tag}>"})

    for attribute, options of @completions.attributes when attribute.indexOf(lowerCasePrefix) is 0
      completions.push({snippet: "#{attribute}=\"$1\"$0", displayText: attribute, type: 'attribute'}) if options.global

    completions

  getAllAttributeValueCompletions: ({editor, bufferPosition}) ->
    completions = []
    values = @getAttributeValues(editor, bufferPosition)
    for value in values
      completions.push({text: value, type: 'value'})
    completions

  getAttributeValueCompletions: ({editor, bufferPosition, prefix}) ->
    completions = []
    values = @getAttributeValues(editor, bufferPosition)
    lowerCasePrefix = prefix.toLowerCase()
    for value in values when value.indexOf(lowerCasePrefix) is 0
      completions.push({text: value, type: 'value'})
    completions

  loadCompletions: ->
    @completions = {}
    fs.readFile path.resolve(__dirname, '..', 'completions.json'), (error, content) =>
      @completions = JSON.parse(content) unless error?
      return

  getPreviousTag: (editor, bufferPosition) ->
    {row} = bufferPosition
    while row >= 0
      tag = tagPattern.exec(editor.lineTextForBufferRow(row))?[1]
      return tag if tag
      row--
    return

  getPreviousAttribute: (editor, bufferPosition) ->
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition]).trim()

    # Remove everything until the opening quote
    quoteIndex = line.length - 1
    quoteIndex-- while line[quoteIndex] and not (line[quoteIndex] in ['"', "'"])
    line = line.substring(0, quoteIndex)

    attributePattern.exec(line)?[1]

  getAttributeValues: (editor, bufferPosition) ->
    attribute = @completions.attributes[@getPreviousAttribute(editor, bufferPosition)]
    attribute?.attribOption ? []

  getTagAttributes: (tag) ->
    @completions.tags[tag]?.attributes ? []
