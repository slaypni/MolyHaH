chrome.runtime.onInstalled.addListener (details) ->
    
chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    switch request.type
        when 'call'
            obj = window
            for prop in request.fnname.split('.')
                obj = obj[prop]
            fn = obj
            response = fn.apply(this, request.args)
            sendResponse(response)
        when 'getTab'
            sendResponse(sender.tab)

