--[[
    双向链表
--]]
local linkList = class("linkList")

-- 构造
function linkList:ctor(dataKey, compFunc)
    self.dataKey = dataKey or "data"
    -- 比较函数
    self.compFunc = compFunc
    -- 首节点
    self.firstNode = nil
    -- 末节点
    self.lastNode = nil
    -- 链表长度
    self.size = 0
end

-- 插入到节点前面
local function insertNodePre(self, newNode, node)
    newNode.pre = node.pre
    newNode.next = node
    local preNode = node.pre
    node.pre = newNode
    if preNode then
        preNode.next = newNode
    else
        self.firstNode = newNode
    end
end

-- 插入到节点后面
local function insertNodeNext(self, newNode, node)

    newNode.pre = node
    local nextNode = node.next
    newNode.next = nextNode
    node.next = newNode

    if nextNode then
        nextNode.pre = newNode
    else
        self.lastNode = newNode
    end
end

-- 比较
local function callCompare(self, newNode, oldNode)
    if "function" == type(self.compFunc) then
        return self.compFunc(newNode, oldNode)
    end
end

----------------API----------------

-- 创建新节点
function linkList.createNode(data, dataKey)
    local key = dataKey or "data"
    return {pre = nil, next = nil, [key] = data, tag = nil}
end

-- 创建新节点
function linkList:newNode(data, dataKey)
    local key = dataKey or self.dataKey
    return {pre = nil, next = nil, [key] = data}
end

-- 设置排序算法
function linkList:setCompare(com)
    self.compFunc = com
end

-- 插入
function linkList:insert(node)
    if node.pre or node.next or node == self:front() then
        svrFunc.exception("linklist:insert: invalid node!")
        return
    end

    local isInsert = false
    local newNode = node
    -- 判断队列是否为空
    if not self:empty() then
        -- 如果不为空
        -- 当前节点
        local curNode = self:front()
        while curNode do
            -- 和当前节点比较
            if callCompare(self, newNode, curNode) then
                insertNodePre(self, newNode, curNode)
                self.size = self.size + 1
                isInsert = true
                break
            else
                if curNode.next then
                    curNode = curNode.next
                else
                    break
                end
            end
        end

        if not isInsert then
            insertNodeNext(self, newNode, curNode)
            self.size = self.size + 1
        end

    else
        -- 如果为空，插入到list中，self.firstNode
        self.firstNode = newNode
        self.lastNode = newNode
        self.size = 1
        return newNode
    end
end

-- 删除
function linkList:remove(node)
    local preNode = node.pre
    local nextNode = node.next
    node.pre = nil
    node.next = nil

    if preNode and nextNode then
        -- 该节点是中间节点
        preNode.next = nextNode
        nextNode.pre = preNode
        self.size = self.size - 1

    elseif preNode and not nextNode then
        -- 该节点是末尾节点
        preNode.next = nil
        self.lastNode = preNode
        self.size = self.size - 1

    elseif not preNode and nextNode then
        -- 该节点是首节点，且有其他节点
        nextNode.pre = nil
        -- 重置firstNode
        self.firstNode = nextNode
        self.size = self.size - 1

    else
        -- 只有首节点
        if self.firstNode == node then
            self.firstNode = nil
            self.lastNode = nil
            self.size = self.size - 1
        else
            if not node.pre and not node.next then
                svrFunc.exception("linklist:remove: invalid node!")
                return
            end
        end
    end
end

-- 清空链表
function linkList:clean()
    self.firstNode = nil
    self.lastNode = nil
    self.size = 0
end

-- 获取首节点
function linkList:front()
    return self.firstNode
end

-- 获取末节点
function linkList:last()
    return self.lastNode
end

-- 删除第一个节点
function linkList:pop()
    local node = self.firstNode
    self:remove(self.firstNode)
    return node
end

-- 排序
function linkList:sort()
    local nextNode = self.firstNode
    linkList.clean(self)
    while nextNode do
        local node = nextNode
        nextNode = nextNode.next
        node.pre = nil
        node.next = nil
        linkList.insert(self, node)
    end
end

-- 获取某个位置的节点
function linkList:getNode(pos)
    if pos and pos <= self:size() then
        local i = 1
        local node = self:front()
        while node do
            if pos == i then
                return node
            end
            i = i + 1
            node = node.next
        end
    end
end

-- 获取节点的位置
function linkList:getPos(node)
    if node and not self:empty() then
        local curNode = self:front()
        local i = 1
        while curNode do
            if node == curNode then
                return i
            end
            i = i + 1
            curNode = curNode.next
        end
    end
end

-- 删除某个位置的节点
function linkList:removePos(pos)
    local node = self:getNode(pos)
    if node then
        self:remove(node)
    end
    return node
end

-- 判断list是否为空
function linkList:empty()
    if not self.firstNode and self.size <=0 then
        return true
    end

    return false
end

-- 获取list的size
function linkList:size()
    return self.size
end

function linkList:dump(title)
    print("============" .. (title or "linklist") .. "===========")
    local function dumpNode(node, title)
        if not node then
            print("node is nil")
        elseif node[self.dataKey].dump then
            node[self.dataKey]:dump(title)
        else
            title = title and title .. ":" or ""
            print(title, node)
            print("\n")
        end
    end

    if not self.firstNode then
        print("list is empty!\n\n\n")
        return
    end

    dumpNode(self.firstNode, "first node")

    local node = self.firstNode
    local i = 2
    while node and node.next do
        node = node.next
        dumpNode(node, "the " .. i .. " node!")
        i = i + 1
    end

    print("\n\n\n")
end

return linkList