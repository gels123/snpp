local filterQueue = class("filterQueue")
 
function filterQueue:ctor()
	self.data = {}
	self.count = 0
end

function filterQueue:push(id, queueData)
	if not self.data[id] then
		self.count = self.count + 1
	end
	self.data[id] = queueData
end

function filterQueue:remove(id)
	local data = self.data[id]
	self.data[id] = nil
	if data then
		self.count = self.count - 1
	end
	return data
end

function filterQueue:has(id)
	if  self.data[id] then
		return true
	end
end

function filterQueue:popAll()
	gLog.d("filterQueue:popAll total=", self.count)
	return self.data
end

return filterQueue