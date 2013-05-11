# require hapt.js, underscore.js

callbg = (cb, fnname, args...) ->
    chrome.runtime.sendMessage {type: 'call', fnname: fnname, args: args}, (response) ->
        cb?(response)

getTab = (cb) ->
    chrome.runtime.sendMessage {type: 'getTab'}, (tab) ->
        cb?(tab)

hapt_listen = (cb) ->
    targets = ['body', 'html']
    focusables = Array.prototype.slice.call(document.querySelectorAll('[tabindex]'), 0) # omitted selector ', a, area, button' for performance
    for f in focusables when not f.isContentEditable
        targets.push(f)
    hapt.listen(cb, window, true, targets)

settings = null
storage.getSettings (_settings) ->
    settings = _settings
       
    listen = ->
        listener = hapt_listen (keys) ->
            _keys = keys.join(' ')
            if _keys in (binding.join(' ') for binding in settings.bindings.enterHah)
                listener.stop()
                listener = null
                hah null, ->
                    listen()
                return false
            if _keys in (binding.join(' ') for binding in settings.bindings.enterHahBg)
                listener.stop()
                listener = null
                hah {active: false}, ->
                    listen()
                return false
            return true
    listen()

###
Enter HaH mode
@param {Object} tab An Object passed to chrome.tabs.create() as createProperties. If null is passed, a link is "clicked" regularly.
@param {Function} cb Called when HaH mode is canceled.
###
hah = (tab_option = null, cb = null) ->
    HINT_CLASS_NAME = 'moly_hah_hint'
    BACK_PANEL_ID = 'moly_hah_backpanel'

    symbols = settings.symbols

    createSymbolSequences = (element_num) ->    
        ###
        @param {Number} element_num Number of target elements.
        @param {Number} symbol_num Numbef of caractors used at Hit-a-Hint.
        ###
        createUniqueSequences = (element_num, symbol_num) ->
            remaining_num = element_num
            queue = []
            dig = (leaf = []) ->
                if remaining_num == 0 then return leaf
                if queue.length != 0
                    remaining_num += 1
                buds_num = _.min([remaining_num, symbol_num])
                for i in [1..buds_num]
                    a = []
                    leaf.push(a)
                    queue.push(a)
                remaining_num -= buds_num
                dig(queue.shift())
                return leaf
     
            sequences = []
            parse = (node = dig(), trace_indices = []) ->
                if node.length == 0 # leaf
                    sequences.push(trace_indices)
                    return
                for i in _.range(node.length)
                    parse(node[i], trace_indices.concat(i))
            parse()
            return sequences

        _symbols = symbols.split('').reverse().join('')
        seqs = createUniqueSequences(element_num, symbols.length)
        shortcuts = for i in _.range(element_num)
            (seqs[i].map (n) -> _symbols[n]).join('')
        return shortcuts.reverse()
    
    createBackPanel = ->
        panel = document.createElement('div')
        panel.id = BACK_PANEL_ID
        return panel

    createHints = ->         
        createHint = (target) ->
            hint = document.createElement('div')
            hint.className = HINT_CLASS_NAME + (if target.tagName.toLowerCase() == 'a' then ' link' else '')
            hint.moly_hah = {
                target: target
                defaultClassName: hint.className
            }
            return hint

        isVisible = (e) ->
            return (e.offsetWidth > 0 or e.offsetHeight > 0) and window.getComputedStyle(e).visibility != 'hidden'

        isInsideDisplay = (e) ->
            pos = e.getBoundingClientRect()
            isInsideX = -1 * e.offsetWidth <= pos.left <= (window.innerWidth or document.documentElement.clientWidth)
            isInsideY = -1 * e.offsetHeight <= pos.top <= (window.innerHeight or document.documentElement.clientHeight)
            return isInsideX and isInsideY

        q = 'a, input:not([type="hidden"]), textarea, button, select, [contenteditable]:not([contenteditable="false"]), [onclick], [onmousedown], [onmouseup], [role="link"], [role="button"]' # not support for: ', area[href], object'
        hints = (createHint(e) for e in Array.prototype.slice.call(document.querySelectorAll(q), 0) when isVisible(e) and isInsideDisplay(e))

        for [hint, shortcut] in _.zip(hints, createSymbolSequences(hints.length))
            hint.textContent = shortcut
        return hints

    quit = ->
        document.querySelector('body').removeChild(panel) if panel?
        listener?.stop()
        cb?()

    panel = createBackPanel()
    document.querySelector('body').appendChild(panel)

    hints = for hint in createHints().reverse()
        setPosition = () ->
            offset = (e) ->
                pos = e.getBoundingClientRect()
                return {left: pos.left + window.scrollX, top: pos.top + window.scrollY}
                
            {left: left, top: top} = offset(hint.moly_hah.target)
            style = window.getComputedStyle(hint)
            client =
                width: window.innerWidth or document.documentElement.clientWidth
                height: window.innerHeight or document.documentElement.clientHeight
            hint.style.left = '' + _.min([_.max([left, window.scrollX]), window.scrollX + client.width - parseInt(style.width)]) + 'px'
            hint.style.top = '' + _.min([_.max([top, window.scrollY]), window.scrollY + client.height - parseInt(style.height)]) + 'px'

        hint.style.zIndex = 2147483647 - panel.childElementCount
        panel.appendChild(hint)
        setPosition()
        hint

    if hints.length == 0
        quit()
        return

    input = ''
    _keys = []
    listener = hapt_listen (keys) ->
        handle_input = ->
            findMatchingHints = ->
                return (h for h in hints when h.textContent.slice(0, input.length) == input)

            click = (elem) ->
                dispatchClickEvent = () ->
                    if tab_option? and elem.href
                        getTab (tab) ->
                            callbg(null, 'chrome.tabs.create', _.extend(tab_option, {url: elem.href, index: tab.index + 1, openerTabId: tab.id}))
                    else
                        for type in ['mousedown', 'mouseup', 'click']
                            ev = document.createEvent('MouseEvents')
                            ev.initEvent(type, true, false)
                            elem.dispatchEvent(ev)
                    
                switch elem.tagName.toLowerCase()
                    when 'a' then dispatchClickEvent()
                    when 'input'
                        attr = elem.getAttribute('type')?.toLowerCase()
                        if attr in ['checkbox', 'radio', 'file', 'submit', 'reset', 'button', 'image']
                            dispatchClickEvent()
                        else
                            elem.focus()
                    when 'textarea', 'select' then elem.focus()
                    else
                        if elem.isContentEditable
                            elem.focus()
                        else
                            dispatchClickEvent()
                quit()

            getRegularClassName = (h) ->
                return HINT_CLASS_NAME + (if h.moly_hah.target.tagName.toLowerCase() in ['a'] then ' link' else '')

            matching_hints = findMatchingHints()
            if matching_hints.length == hints.length
                for h in hints
                    h.className = h.moly_hah.defaultClassName
            else if matching_hints.length > 1
                for h in hints
                    h.className = h.moly_hah.defaultClassName + ' ' + (if h in matching_hints then 'matching' else 'not-matching')
            else if matching_hints.length == 1
                click(matching_hints[0].moly_hah.target)

        if not _.isEqual(keys, _keys)
            keys = _.difference(keys, _keys)
        _keys = (k for k in keys when k.length == 1)

        if keys.join(' ') in (binding.join(' ') for binding in settings.bindings.quitHah)
            quit()
            return false
        else if keys[0] == 'BackSpace'
            if input.length == 0
                quit()
            else
                input = input.substring(0, input.length - 1)
                handle_input()
            return false
        else if keys.length == 1 and keys[0].length == 1 and keys[0] in symbols
            input += keys[0]
            handle_input()
            return false
            
        return true
