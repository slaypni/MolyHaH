import * as storage from './storage'

chrome.runtime.onInstalled.addListener (details) ->
    
chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    switch request.type
        when 'chrome.tabs.create'
            response = chrome.tabs.create(request.arg)
            sendResponse(response)
        when 'getTab'
            sendResponse(sender.tab)
        when 'getSettings'
            storage.getSettings (settings) ->
                sendResponse(settings)
        when 'setSettings'
            storage.setSettings request.settings, (settings) ->
                sendResponse(settings)
    return true
