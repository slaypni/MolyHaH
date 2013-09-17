# require hapt.js, underscore.js

callbg = (cb, fnname, args...) ->
    chrome.runtime.sendMessage {type: 'call', fnname: fnname, args: args}, (response) ->
        cb?(response)

getTab = (cb) ->
    chrome.runtime.sendMessage {type: 'getTab'}, (tab) ->
        cb?(tab)

hapt_listen = (cb) ->
    hapt.listen( (keys, event) ->
        if not (event.target.isContentEditable or event.target.nodeName.toLowerCase() in ['textarea', 'input', 'select'])
            return cb(keys, event)
        return true
    , window, true, [])

settings = null
chrome.runtime.sendMessage {type: 'getSettings'}, (_settings) ->
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
        @param {Number} symbol_num Number of characters used at Hit-a-Hint.
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
            hint.className = HINT_CLASS_NAME + (if target.nodeName.toLowerCase() == 'a' then ' moly_hah_link' else '')
            hint.moly_hah = {
                target: target
                defaultClassName: hint.className
            }
            return hint

        isVisible = (e) ->
            return (e.offsetWidth > 0 or e.offsetHeight > 0) and window.getComputedStyle(e).visibility != 'hidden'

        isInsideDisplay = (e) ->
            pos = e.getBoundingClientRect()
            isInsideX = -1 * e.offsetWidth <= pos.left < (window.innerWidth or document.documentElement.clientWidth)
            isInsideY = -1 * e.offsetHeight <= pos.top < (window.innerHeight or document.documentElement.clientHeight)
            return isInsideX and isInsideY

        targets = (e for e in Array.prototype.slice.call(document.querySelectorAll('*'), 0) when window.getComputedStyle(e).cursor == 'pointer')
        q = 'a, input:not([type="hidden"]), textarea, button, select, [contenteditable]:not([contenteditable="false"]), [onclick], [onmousedown], [onmouseup], [role="link"], [role="button"]' # not support for: ', area[href], object'
        targets = (e for e in _.union(Array.prototype.slice.call(document.querySelectorAll(q), 0), targets) when isVisible(e) and isInsideDisplay(e))

        # if element A is descendant of element B, element A is dismissed
        filter = ->
            _targets = []
            for elem in targets
                e = elem
                while (e = e.parentElement)?
                    if e in targets then break
                if not e? then _targets.push(elem)
            return _targets
        hints = (createHint(e) for e in filter())

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
            client =
                width: window.innerWidth or document.documentElement.clientWidth
                height: window.innerHeight or document.documentElement.clientHeight
            hint.style.left = '' + _.min([_.max([left, window.scrollX]), window.scrollX + client.width - hint.offsetWidth]) + 'px'
            hint.style.top = '' + _.min([_.max([top, window.scrollY]), window.scrollY + client.height - hint.offsetHeight]) + 'px'

        hint.style.zIndex = 2147483647 - panel.childElementCount
        panel.appendChild(hint)
        setPosition()
        hint

    if hints.length == 0
        quit()
        return

    input = ''
    _keys = []
    listener = hapt_listen (keys, event) ->
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
                            ev.initMouseEvent(type, true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, null)
                            elem.dispatchEvent(ev)
                    
                switch elem.nodeName.toLowerCase()
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
                return HINT_CLASS_NAME + (if h.moly_hah.target.nodeName.toLowerCase() in ['a'] then ' link' else '')

            matching_hints = findMatchingHints()
            if matching_hints.length == 1 and input == matching_hints[0].textContent
                click matching_hints[0].moly_hah.target
            else if matching_hints.length == hints.length
                for h in hints
                    h.className = h.moly_hah.defaultClassName
                    h.innerHTML = h.textContent
            else if matching_hints.length > 1
                for h in hints
                    h.className = h.moly_hah.defaultClassName + ' ' + (if h in matching_hints then 'moly_hah_matching' else 'moly_hah_not-matching')
                    h.innerHTML = "<span class=\"moly_hah_partial_matching\">#{h.textContent[..input.length-1]}</span>#{h.textContent[input.length..]}"
            else if matching_hints.length == 0
                input = input.slice 0, -1

        key = String.fromCharCode event.keyCode

        if (settings.bindings.quitHah.some (binding) -> _.isEqual keys, binding)
            quit()
            return false
        else if keys[0] == 'BackSpace'
            if input.length == 0
                quit()
            else
                input = input.slice 0, -1
                handle_input()
            return false
        else if key in symbols
            input += key
            handle_input()
            return false
            
        return true
