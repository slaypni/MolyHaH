###
----------------------------------------
Hapt
A key bindings listener for JavaScript.
----------------------------------------

The MIT License (MIT)

Copyright (c) 2013 slaypni

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

MODIFIERS = [
    16,  # Shift
    17,  # Ctrl
    18,  # Alt
    91,  # Command
    92   # Meta
]

SHORTCUTS =
    16:  'Shift'
    17:  'Ctrl'
    18:  'Alt'
    91:  'Command'
    92:  'Meta'
    8:   'BackSpace'
    9:   'Tab'
    13:  'Enter'
    19:  'Pause'
    20:  'CapsLock'
    27:  'Esc'
    32:  'Space'
    33:  'PageUp'
    34:  'PageDown'
    35:  'End'
    36:  'Home'
    37:  'Left'
    38:  'Up'
    39:  'Right'
    40:  'Down'
    42:  'PrintScreen'
    45:  'Insert'
    46:  'Delete'
    96:  'Num0'
    97:  'Num1'
    98:  'Num2'
    99:  'Num3'
    100: 'Num4'
    101: 'Num5'
    102: 'Num6'
    103: 'Num7'
    104: 'Num8'
    105: 'Num9'
    106: 'Mul'
    107: 'Add'
    109: 'Sub'
    110: 'Dec'
    111: 'Div'
    112: 'F1'
    113: 'F2'
    114: 'F3'
    115: 'F4'
    116: 'F5'
    117: 'F6'
    118: 'F7'
    119: 'F8'
    120: 'F9'
    121: 'F10'
    122: 'F11'
    123: 'F12'
    124: 'F13'
    125: 'F14'
    126: 'F15'
    144: 'NumLock'
    145: 'ScrollLock'
    186: ';'
    187: '='
    188: ','
    189: '-'
    190: '.'
    191: '/'
    192: '`'
    219: '['
    220: '\\'
    221: ']'
    222: "'"

class _KeyState
    constructor: ->
        @pressed_keys = {}

    clear: =>
        @pressed_keys = {}

    event_handler: (event) =>
        keycode = parseInt(event.which ? event.keyCode)

        down = =>
            if @pressed_keys.hasOwnProperty(keycode)
                return false
            @pressed_keys[keycode] = event
            return true

        up = =>
            if @pressed_keys.hasOwnProperty(keycode)
                delete @pressed_keys[keycode]
            return true

        switch event.type.toLowerCase()
            when 'keydown' then return down()
            when 'keyup' then return up()

    keys: =>
        describe = (code) =>
            return SHORTCUTS[code] ? String.fromCharCode(code)

        modifier_keys = (describe(i) for i in MODIFIERS when @pressed_keys.hasOwnProperty(i))
        regular_keys = (parseInt(i) for i, _e of @pressed_keys when parseInt(i) not in MODIFIERS).sort().map (i) -> describe(i)
            
        return modifier_keys.concat(regular_keys)


###
Listen Key events.

@param {Function} cb Handler called when key events occured.
    @param {String[]} keys Shortcut names of pressed keys.
    @param {Event} event
    @return {Boolean} if the value was false, the caller prevents default action and event propagation.
@param {EventTarget} doc The target calls addEventListener().
@param {Boolean} useCapture Passed into addEventListener().
@param {(Element|String)[]} targets Key events to the target listed in this param can call callback handler.
    If the value was an empty array, events to any target will call callback handler.
###
listen = (cb, doc = window, useCapture = true, targets = ['body', 'html']) ->
    state = new _KeyState()

    cancel = ->
        state.clear()
        return true

    if targets?.length
        target_tagnames = (t.toLowerCase() for t in targets when typeof t == 'string')
        target_elements = (t for t in targets when typeof t == 'object')

    keydown_listener = (event) ->
        isTargetTagname = ->
            tagName = event.target.tagName.toLowerCase()
            target_tagnames.some (t) ->
                t == tagName

        isTargetElement = ->
            target_elements.some (t) ->
                 t == event.target
        
        if targets?.length and not (isTargetTagname() or isTargetElement())
            return true
        
        if state.event_handler(event)
            if cb(state.keys(), event) == false
                event.preventDefault()
                event.stopImmediatePropagation()
        return true

    keyup_listener = (event) ->
        state.event_handler(event)

    stop = ->
        cancel()
        doc.removeEventListener('keydown', keydown_listener, useCapture);
        doc.removeEventListener('keyup', keyup_listener, useCapture);
        doc.removeEventListener('blur', cancel, useCapture)
        doc.removeEventListener('focus', cancel, useCapture)

    doc.addEventListener('keydown', keydown_listener, useCapture)
    doc.addEventListener('keyup', keyup_listener, useCapture)
    doc.addEventListener('blur', cancel, useCapture)
    doc.addEventListener('focus', cancel, useCapture)

    return {
        cancel: cancel
        stop: stop
    }
    
@hapt = {
    listen: listen
}
