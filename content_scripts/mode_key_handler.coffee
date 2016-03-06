# Example key mapping (@keyMapping):
#   i:
#     command: "enterInsertMode", ... # This is a registryEntry object (as too are the other commands).
#   g:
#     g:
#       command: "scrollToTop", ...
#     t:
#       command: "nextTab", ...
#
# This key-mapping structure is generated by Commands.generateKeyStateMapping() and may be arbitrarily deep.
# Observe that @keyMapping["g"] is itself also a valid key mapping.  At any point, the key state (@keyState)
# consists of a (non-empty) list of such mappings.

class KeyHandlerMode extends Mode
  keydownEvents: {}
  setKeyMapping: (@keyMapping) -> @reset()
  setPassKeys: (@passKeys) -> @reset()
  # Only for tests.
  setCommandHandler: (@commandHandler) ->

  # Reset the key state, optionally retaining the count provided.
  reset: (@countPrefix = 0) ->
    bgLog "Clearing key state, set count=#{@countPrefix}."
    @keyState = [@keyMapping]

  constructor: (options) ->
    @commandHandler = options.commandHandler ? (->)
    @setKeyMapping options.keyMapping ? {}

    super extend options,
      keydown: @onKeydown.bind this
      keypress: @onKeypress.bind this
      keyup: @onKeyup.bind this
      # We cannot track keyup events if we lose the focus.
      blur: (event) => @alwaysContinueBubbling => @keydownEvents = {} if event.target == window

  onKeydown: (event) ->
    keyChar = KeyboardUtils.getKeyCharString event
    isEscape = KeyboardUtils.isEscape event
    if isEscape and @countPrefix == 0 and @keyState.length == 1
      @continueBubbling
    else if isEscape
      @keydownEvents[event.keyCode] = true
      @reset()
      false # Suppress event.
    else if @isMappedKey keyChar
      @keydownEvents[event.keyCode] = true
      @handleKeyChar keyChar
    else if not keyChar and (keyChar = KeyboardUtils.getKeyChar event) and
        (@isMappedKey(keyChar) or @isCountKey keyChar)
      # We will possibly be handling a subsequent keypress event, so suppress propagation of this event to
      # prevent triggering page event listeners (e.g. Google instant Search).
      @keydownEvents[event.keyCode] = true
      DomUtils.suppressPropagation event
      @stopBubblingAndTrue
    else
      @continueBubbling

  onKeypress: (event) ->
    keyChar = KeyboardUtils.getKeyCharString event
    if @isMappedKey keyChar
      @handleKeyChar keyChar
    else if @isCountKey keyChar
      digit = parseInt keyChar
      @reset if @keyState.length == 1 then @countPrefix * 10 + digit else digit
      false # Suppress event.
    else
      @reset()
      @continueBubbling

  onKeyup: (event) ->
    return @continueBubbling unless event.keyCode of @keydownEvents
    delete @keydownEvents[event.keyCode]
    DomUtils.suppressPropagation event
    @stopBubblingAndTrue

  # This tests whether there is a mapping of keyChar in the current key state (and accounts for pass keys).
  isMappedKey: (keyChar) ->
    (mapping for mapping in @keyState when keyChar of mapping)[0]? and not @isPassKey keyChar

  # This tests whether keyChar is a digit (and accounts for pass keys).
  isCountKey: (keyChar) ->
    keyChar and (if 0 < @countPrefix then '0' else '1') <= keyChar <= '9' and not @isPassKey keyChar

  # Keystrokes are *never* considered pass keys if the user has begun entering a command.  So, for example, if
  # 't' is a passKey, then the "t"-s of 'gt' and '99t' are neverthless handled as regular keys.
  isPassKey: (keyChar) ->
    @countPrefix == 0 and @keyState.length == 1 and keyChar in (@passKeys ? "")

  handleKeyChar: (keyChar) ->
    bgLog "Handling key #{keyChar}, mode=#{@name}."
    # A count prefix applies only so long a keyChar is mapped in @keyState[0]; e.g. 7gj should be 1j.
    @countPrefix = 0 unless keyChar of @keyState[0]
    # Advance the key state.  The new key state is the current mappings of keyChar, plus @keyMapping.
    @keyState = [(mapping[keyChar] for mapping in @keyState when keyChar of mapping)..., @keyMapping]
    command = (mapping for mapping in @keyState when "command" of mapping)[0]
    if command
      count = if 0 < @countPrefix then @countPrefix else 1
      bgLog "Calling mode=#{@name}, command=#{command.command}, count=#{count}."
      @reset()
      @commandHandler {command, count}
    false # Suppress event.

root = exports ? window
root.KeyHandlerMode = KeyHandlerMode
