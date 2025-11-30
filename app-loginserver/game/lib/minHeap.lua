--[[
    最小堆
    eg1:
        local minHeap = require("minHeap").new()
        minHeap:push(100)
        minHeap:push(20)
        minHeap:push(100)
        print("top1=", minHeap:pop())

    eg2:
        local minHeap = require("minHeap").new(function (node1, node2)
            return node1 and node2 and node1.num < node2.num
        end)
        minHeap:push({num = 55})
        minHeap:push({num = 1})
        minHeap:push({num = 45})
        print("top1=", minHeap:pop().num)
]]
local minHeap = class("minHeap")

function minHeap:ctor(cmp)
    self._data = {}
    self._dataSize = 0

    -- 比较函数
    self._cmp = cmp or function(node1, node2) return node1 < node2 end
end

-- push
function minHeap:push(node)
    if node then
        self._dataSize = self._dataSize  +  1
        table.insert(self._data, node)
        self:percolateUp(self._dataSize)
    end
    return self
end

function minHeap:percolateUp(index)
    if index <= 1 then
        if index ~= 1 then
            print("minHeap:percolateUp: sort error")
        end
        return true
    end
    local pIndex
    if index % 2 == 0 then
        pIndex = index / 2
    else
        pIndex = (index - 1) / 2
    end
    if not self._cmp(self._data[pIndex], self._data[index]) then
        self._data[pIndex], self._data[index] = self._data[index], self._data[pIndex]
        self:percolateUp(pIndex)
    end
end

-- pop
function minHeap:pop()
    local root
    if self._dataSize > 0 then
        root = self._data[1]
        self._data[1] = self._data[self._dataSize]
        self._data[self._dataSize] = nil
        self._dataSize = self._dataSize - 1
        if self._dataSize > 1 then
            self:percolateDown(1)
        end
    end
    return root
end

function minHeap:percolateDown(index)
    local lfIndex, rtIndex, minIndex
    lfIndex = index * 2
    rtIndex = lfIndex + 1
    if rtIndex > self._dataSize then
        if lfIndex > self._dataSize then
            return
        else 
            minIndex = lfIndex
        end
    else
        if self._cmp(self._data[lfIndex], self._data[rtIndex]) then
            minIndex = lfIndex
        else
            minIndex = rtIndex
        end
    end
    if not self._cmp(self._data[index], self._data[minIndex]) then
        self._data[index], self._data[minIndex] = self._data[minIndex], self._data[index]
        self:percolateDown(minIndex)
    end
end

-- Restores the `Heap` property.
function minHeap:heapify(node)
    if self._dataSize <= 0 then
        return
    end
    if node then
        local i
        for k,v in pairs(self._data) do
            if v == node then
                i = k
                break
            end
        end
        -- print("minHeap:heapify", node, i)
        if i then 
            self:percolateDown(i)
            self:percolateUp(i)
        end
        return
    end
    for i = math.floor(self._dataSize/2), 1, -1 do
        self:percolateDown(i)
    end
    return self
end

function minHeap:size()
    return self._dataSize
end

function minHeap:clear()
    self._data = {}
    self._dataSize = 0
end

return minHeap
