
local Component = import("..Component")
local NewEventProtocol = class("NewEventProtocol", Component)

function NewEventProtocol:ctor()
    NewEventProtocol.super.ctor(self, "NewEventProtocol")

    self._debug = false
    self._mapListeners = {} -- key:eventName value:listener
    self._mapEventNames = {} -- key:listenId value:eventName
    self._dispatch = {} -- key:eventName value:bool
    self._weakObjs = {__mode = "v"}
    self._listenId = 0
end

function NewEventProtocol:printD(...)
    if self._debug then
        print(...)
    end
end

function NewEventProtocol:genListenId()
    self._listenId = self._listenId + 1
    return self._listenId
end

function NewEventProtocol:addEventListener(eventName, handler)
    assert(type(eventName) == "string" and eventName ~= "", "NewEventProtocol:addEventListener - invalid eventName")
    assert(type(handler) == "function", "NewEventProtocol:addEventListener - invalid listener")
    
    -- 拆解对象和函数以及弱引用
    local val1, method = debug.getupvalue(handler, 1)
    local val2, obj = debug.getupvalue(handler, 2)
    local bWeakRef = false
    if val1 == "method" and val2 == "obj" and method and obj then
        bWeakRef = true
    else
        method = handler
    end

    -- 某事件的表
    self._mapListeners[eventName] = self._mapListeners[eventName] or {}
    local listeners = self._mapListeners[eventName]
    local listenId = self:genListenId()
    table.insert(listeners, {listenId=listenId, method=method, bWeakRef=bWeakRef})
    self._mapEventNames[listenId] = eventName

    -- 弱引用
    if bWeakRef then
        self._weakObjs[listenId] = obj
    end

    self:printD("EventProtocol:addEventListener - event=", eventName, "listenId=", listenId)

    return listenId
end

function NewEventProtocol:dispatchEvent(event)
    local eventName = tostring(event.name)
    local listeners = self._mapListeners[eventName]
    if not listeners then
        self:printD("EventProtocol:dispatchEvent - invalid event=", eventName)
        return
    end

    local min = next(listeners)
    local max = #listeners
    if min and max and min > 0 and max > 0 then
        self:beforeDispatch(eventName)
        for i = min, max do
            local listener = listeners[i]
            if listener and listener.listenId > 0 and listener.method then
                local obj = self._weakObjs[listener.listenId]
                self:printD("EventProtocol:dispatchEvent - fire event=", eventName, "listenId=", listener.listenId)
                if listener.bWeakRef and obj then
                    listener.method(obj, event)
                else
                    listener.method(event)
                end
            end
        end
        self:afterDispatch(eventName)
    end
end

function NewEventProtocol:removeEventListener(listenId)
    local eventName = self._mapEventNames[listenId]
    if not eventName then
        return
    end

    local listeners = self._mapListeners[eventName]
    if not listeners then
        return
    end

    -- 正在回调 只打删除标记
    local bDispatching = self:isDispatching(eventName)
    for i, listener in pairs(listeners) do
        if listener.listenId == listenId then
            if bDispatching then
                listener.bDel = true
                self:printD("NewEventProtocol:removeEventListener - set bDel event=", eventName, "listenId=", listenId)
            else
                self._mapListeners[eventName][i] = nil
                self._mapEventNames[listenId] = nil
                self._weakObjs[listenId] = nil
            end
            break
        end
    end
end

function NewEventProtocol:removeEventListenersByEvent(eventName)
    local eventName = tostring(eventName)
    local listeners = self._mapListeners[eventName]
    if not listeners then
        self:printD("NewEventProtocol:removeEventListenersByEvent - invalid event=", eventName)
        return
    end


    local bDispatching = self:isDispatching(eventName)
    for _, listener in ipairs(listeners) do
        if bDispatching then
            listener.bDel = true
        else
            self._mapEventNames[listener.listenId] = nil
            self._weakObjs[listener.listenId] = nil
        end
    end

    if not bDispatching then
        self._mapListeners[eventName] = nil
        self:printD("NewEventProtocol:removeEventListenersByEvent - by event=", eventName)
    end
end

function NewEventProtocol:removeAllEventListeners()
    self:printD("NewEventProtocol:removeAllEventListeners")
    for eventName, _ in pairs(self._mapListeners) do
        self:removeEventListenersByEvent(eventName)
    end
end

function NewEventProtocol:hasEventListener(eventName)
    local eventName = tostring(eventName)
    local listeners = self._mapListeners[eventName]
    if "table" == type(listeners) and next(listeners) then
        return true
    end

    return false
end

function NewEventProtocol:dumpAllEventListeners()
    print(table2string(self._mapListeners, "dumpAllEventListeners", 10))
end

-- 是否回调中
function NewEventProtocol:isDispatching(eventName)
    if not self._dispatch[eventName] then
        return false
    end

    return self._dispatch[eventName] > 0;
end

function NewEventProtocol:beforeDispatch(eventName)
    self._dispatch[eventName] = self._dispatch[eventName] or 0
    self._dispatch[eventName] = self._dispatch[eventName] + 1
end

function NewEventProtocol:afterDispatch(eventName)
    if not self._dispatch[eventName] then
        return
    end

    self._dispatch[eventName] = self._dispatch[eventName] - 1
    if self._dispatch[eventName] == 0 then
        local listeners = self._mapListeners[eventName]
        for i, listener in ipairs(listeners) do
            if listener.bDel then
                table.remove(listeners, i)
            end
        end
    end
end

function NewEventProtocol:exportMethods()
    self:exportMethods_({
        "addEventListener",
        "dispatchEvent",
        "removeEventListener",
        "removeEventListenersByEvent",
        "removeAllEventListeners",
        "hasEventListener",
        "dumpAllEventListeners",
    })
    return self.target_
end

return NewEventProtocol
