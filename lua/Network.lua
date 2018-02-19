-------------------------------------------------------------------------------------------
-- TerraME - a software platform for multiple scale spatially-explicit dynamic modeling.
-- Copyright (C) 2001-2016 INPE and TerraLAB/UFOP -- www.terrame.org

-- This code is part of the TerraME framework.
-- This framework is free software; you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.

-- You should have received a copy of the GNU Lesser General Public
-- License along with this library.

-- The authors reassure the license terms regarding the warranties.
-- They specifically disclaim any warranties, including, but not limited to,
-- the implied warranties of merchantability and fitness for a particular purpose.
-- The framework provided hereunder is on an "as is" basis, and the authors have no
-- obligation to provide maintenance, support, updates, enhancements, or modifications.
-- In no event shall INPE and TerraLAB / UFOP be held liable to any party for direct,
-- indirect, special, incidental, or consequential damages arising out of the use
-- of this software and its documentation.
--
-------------------------------------------------------------------------------------------

-- Support variables
local targetLines
local computedLines -- without taget lines

-- User-defined functions
local inside
local outside

local function createLineInfo(line)
	return {
		id = line.FID,
		geom = line.geom:getGeometryN(0),
		npoints = line.geom:getNPoints(),
		cell = line
	}
end

local function createLinesInfo(lines)
	local linesInfo = {}

	forEachCell(lines, function(line)
		linesInfo[line.FID] = createLineInfo(line)
	end)

	return linesInfo
end

local function createClosestPoint(targetPoint, targetLine)
	local closestPoint = targetPoint:closestPoint(targetLine.geom)
	return {id = closestPoint:asText(), point = closestPoint}
end

local function addTargetInfoInLine(targetLine, closestPoint, distance)
	targetLine.closestPoint = closestPoint
	targetLine.shortestPath = distance
	targetLines[targetLine.id] = targetLine
end

local function createTargetNode(point, distance, line, targetId)
	return {
		target = true,
		id = point:asText(),
		point = point,
		distance = distance,
		line = line, -- lines which the point belongs
		targetId = targetId
	}
end

local function createNode(point, distance, line, position, targetId)
	return {
		id = point:asText(),
		point = point,
		distance = distance,
		line = line, -- lines which the point belongs
		pos = position,
		targetId = targetId
	}
end

local function findClosestLine(lines, point)
	local minDistance = math.huge
	local closestLine
	forEachElement(lines, function(_, line)
		local distance = point:distance(line.geom)
		if minDistance > distance then
			minDistance = distance
			closestLine = line
		end
	end)

	if outside then
		minDistance = outside(minDistance)
	end

	return {line = closestLine, distance = minDistance}
end

local function checkAndRemoveTargetIfLineHasMoreThanOneOfIt(targets)
	local targetList = {}
	for _, node in pairs(targets) do
		table.insert(targetList, node)
	end

	local targetsToRemove = {}

	for i = 1, #targetList do
		local n1 = targetList[i]
		if not targetsToRemove[n1.id] then
			for j = i + 1, #targetList do
				local n2 = targetList[j]
				if not targetsToRemove[n2.id] then
					if n1.line.id == n2.line.id then
						local dist = n1.point:distance(n2.point)

						if inside then
							dist = inside(dist, n1.line.cell)
						end

						if (n1.distance > dist) and (n1.distance > n2.distance) then
							targetsToRemove[n1.id] = true
						elseif (n2.distance > dist) and (n2.distance > n1.distance) then
							targetsToRemove[n2.id] = true
						end
					end
				end
			end
		end
	end

	for id, node in pairs(targets) do
		if targetsToRemove[id] then
			customWarning("Line '"..node.line.id.."' has more than one target. Target '"..node.targetId
							.."' is too far with distance '"..node.distance.."' and it was removed.")
			targets[id] = nil
		end
	end
end

-- TODO(avancinirodrigo): this method can be improved by some tree
local function findAndAddTargetNodes(self)
	self.netpoints = {}

	forEachCell(self.target, function(target)
		local targetPoint = target.geom:getGeometryN(0)
		local targetId = tonumber(target:getId())
		local closestLine = findClosestLine(self.lines, targetPoint)
		local targetLine = closestLine.line
		local closestPoint = createClosestPoint(targetPoint, closestLine.line)

		addTargetInfoInLine(closestLine.line, closestPoint, closestLine.distance)

		self.netpoints[closestPoint.id] = createTargetNode(closestPoint.point,
												targetLine.shortestPath, targetLine, targetId)
	end)

	checkAndRemoveTargetIfLineHasMoreThanOneOfIt(self.netpoints)
end

local function checkIfLineCrosses(lineA, lineB)
	return lineA.geom:crosses(lineB.geom)
end

local function calculateMinDistance(endpointsA, endpointsB)
	local distances = {}
	distances[1] = endpointsA.first:distance(endpointsB.first)
	distances[2] = endpointsA.first:distance(endpointsB.last)
	distances[3] = endpointsA.last:distance(endpointsB.first)
	distances[4] = endpointsA.last:distance(endpointsB.last)

	local minDistance = math.huge

	for i = 1, 4 do
		if minDistance > distances[i] then
			minDistance = distances[i]
		end
	end

	return minDistance
end

local function validateLine(self, line, linesEndpoints, linesValidated, linesConnected)
	linesEndpoints[line.id] = {first = line.geom:getStartPoint(), last = line.geom:getEndPoint()}
	local lineMinDistance = math.huge

	forEachElement(self.lines, function(_, oline)
		if oline.id == line.id then return end

		if checkIfLineCrosses(line, oline) then
			customError("Lines '"..line.id.."' and '"..oline.id.."' cross each other.")
		end

		if not linesEndpoints[oline.id] then
			linesEndpoints[oline.id] = {first = oline.geom:getStartPoint(), last = oline.geom:getEndPoint()}
		end

		local minDistance = calculateMinDistance(linesEndpoints[line.id], linesEndpoints[oline.id])

		if minDistance <= self.error then
			linesValidated[line.id] = true
			if not linesConnected[oline.id] then
				linesConnected[oline.id] = {}
				table.insert(linesConnected[oline.id], oline.id)
			end

			table.insert(linesConnected[oline.id], line.id)
		elseif lineMinDistance > minDistance then
			lineMinDistance = minDistance
		end
	end)

	if not linesValidated[line.id] then
		customError("Line '"..line.id.."' does not touch any other line. The minimum distance found was: "..lineMinDistance..".")
	end
end

local function hasConnection(linesA, linesB)
	for a = 1, #linesA do
		for b = 1, #linesB do
			if linesA[a] == linesB[b] then
				return true
			end
		end
	end

	return false
end

local function valueExists(tbl, value)
	for i = 1, #tbl do
		if tbl[i] == value then
			return true
		end
	end

	return false
end

local function joinLines(linesA, linesB)
	for i = 1, #linesB do
		if not valueExists(linesA, linesB[i]) then
			table.insert(linesA, linesB[i])
		end
	end
end

local function isNetworkConnected(linesConnected)
	forEachElement(linesConnected, function(a, linesA)
		if not linesA then return end

		forEachElement(linesConnected, function(b, linesB)
			if a ~= b and linesB and hasConnection(linesA, linesB) then
				joinLines(linesA, linesB)
				linesConnected[b] = false
			end
		end)
	end)

	forEachElement(linesConnected, function(id)
		if not linesConnected[id] then
			linesConnected[id] = nil
		end
	end)

	if getn(linesConnected) > 1 then
		return false
	end

	return true
end

local function addNetIdInfo(netIdName, cs, linesConnected)
	local netId = 0
	for _, v in pairs(linesConnected) do
		forEachCell(cs, function(cell)
			if not cell[netIdName] then
				for i = 1, #v do
					if cell.FID == v[i] then
						cell[netIdName] = netId
					end
				end
			end
		end)
		netId = netId + 1
	end
end

local function saveErrorInfo(self, linesConnected)
	local gis = getPackage("gis")
	local linesCs = self.linesCs
	local errorLayerName = "neterror"
	local netIdName = "net_id"
	local errMsg

	if linesCs.project then
		addNetIdInfo(netIdName, linesCs, linesConnected)
		linesCs:save(errorLayerName, netIdName)
		errMsg = "Layer '"..errorLayerName.."' was automatically created with attribute '"
				..netIdName.."' containing the separated networks."
	else
		local proj = gis.Project{
			file = "network_report.tview",
			clean = true,
			author = "TerraME-Network",
			title = "Error Report"
		}

		local linesCsLayer = gis.Layer{
			project = proj,
			name = errorLayerName,
			file = linesCs.file
		}

		local cs = CellularSpace{
			project = proj,
			layer = linesCsLayer.name,
			missing = linesCs.missing
		}

		addNetIdInfo(netIdName, cs, linesConnected)
		cs:save(linesCsLayer.name, netIdName)
		proj.file:delete()
		errMsg = "Data '"..errorLayerName.."."..File(linesCsLayer.file):extension()
				.. "' was automatically created with attribute '"
				..netIdName.."' containing the separated networks."
	end

	return errMsg
end

local function validateLines(self)
	local linesEndpoints = {}
	local linesValidated = {}
	local linesConnected = {}

	forEachElement(self.lines, function(_, line)
		validateLine(self, line, linesEndpoints, linesValidated, linesConnected)
	end)

	if not isNetworkConnected(linesConnected) then
		local errMsg = saveErrorInfo(self, linesConnected)
		customError("The network is disconnected. "..errMsg)
	end
end

local function findFirstPoint(targetNode)
	local line = targetNode.line
	local pointInfo = {}
	pointInfo.distance = math.huge

	for i = 0, line.npoints - 1 do
		local point = line.geom:getPointN(i)
		local distance = targetNode.point:distance(point)

		if (pointInfo.distance > distance) and (distance > 0) then
			pointInfo.point = point
			pointInfo.distance = distance
			pointInfo.pos = i
		end
	end

	if inside then
		pointInfo.distance = inside(pointInfo.distance, targetNode.line.cell)
	end

	return pointInfo
end

local function calculateFullDistance(node, point, line)
	local distance = node.point:distance(point) -- TODO: this can be improved using delta distance

	if inside then
		distance = inside(distance, line.cell)
	end

	return node.distance + distance
end

local function linkNodeToNext(node, nextNode)
	node.next = nextNode
	node.targetId = nextNode.targetId

	if nextNode.previous then
		if nextNode.router then
			table.insert(nextNode.previous, node)
		else
			nextNode.router = true
			local nextNodePrevious = nextNode.previous
			nextNode.previous = {}
			table.insert(nextNode.previous, nextNodePrevious)
			table.insert(nextNode.previous, node)
		end
	else
		nextNode.previous = node
	end
end

local function nodeExists(node)
	return node ~= nil
end

local function relinkToNextNode(node, nextNode, newDistance)
	nextNode.distance = newDistance

	linkNodeToNext(nextNode, node)

	if not nextNode.router then
		nextNode.previous = nil
	end
end

local reviewRouterNode -- forward function

local function recalculatePreviousDistances(node, previousNode)
	if not previousNode then
		return
	end

	if previousNode.router then
		reviewRouterNode(previousNode, node)
		return
	end

	previousNode.distance = calculateFullDistance(node, previousNode.point, previousNode.line)
	previousNode.targetId = node.targetId
	recalculatePreviousDistances(previousNode, previousNode.previous)
end

local function removeOldRoute(routerNode, node) -- TODO: improve this name
	routerNode.line = node.line

	for i = 1, #routerNode.previous do
		if routerNode.previous[i].line.id == node.line.id then
			table.remove(routerNode.previous, i)
			return
		end
	end
end

local function convertRouterNodeToSimple(routerNode)
	local routerNodePrevious =  routerNode.previous[1]
	routerNode.previous = routerNodePrevious
	routerNode.router = nil
end

reviewRouterNode = function(routerNode, node)
	removeOldRoute(routerNode, node)

	for i = 1, #routerNode.previous do
		if routerNode.targetId ~= routerNode.previous[i].targetId then
			recalculatePreviousDistances(routerNode, routerNode.previous[i])
		end
	end

	if #routerNode.previous == 1 then
		convertRouterNodeToSimple(routerNode)
	end
end

local function reviewNextNodes(node, nextNode)
	if nextNode.target then
		if node.id == nextNode.first.id then
			nextNode.first = nil
		elseif node.id == nextNode.second.id then
			nextNode.second = nil
		else
			customError("Unforeseen error!") -- SKIP : TODO: it needs a test
		end

		return
	end

	local newDistance = calculateFullDistance(node, nextNode.point, node.line)

	if nextNode.distance > newDistance then
		local nextNodeNext = nextNode.next
		relinkToNextNode(node, nextNode, newDistance)
		reviewNextNodes(nextNode, nextNodeNext)
	elseif not nextNode.router then
		nextNode.previous = nil
	end

	if nextNode.router then
		reviewRouterNode(nextNode, node)
	end
end

local function reviewExistingNode(existingNode, currNode, newPosition, newLine)
	local newDistance = calculateFullDistance(currNode, existingNode.point, currNode.line)

	if existingNode.distance > newDistance then
		local existingNodeNext = existingNode.next
		relinkToNextNode(currNode, existingNode, newDistance)

		if newLine.npoints == 2 then
			existingNode.line = newLine
		else
			existingNode.line = currNode.line
		end

		existingNode.pos = newPosition
		reviewNextNodes(existingNode, existingNodeNext)
	else
		reviewNextNodes(existingNode, currNode)
	end
end

local function createNodeByNextPoint(point, position, currNode, line)
	local totalDistance = calculateFullDistance(currNode, point, line)
	return createNode(point, totalDistance, line, position, currNode.targetId)
end

local function addAllNodesOfLineBackward(graph, line, node, nodePosition)
	if nodePosition == 0 then return end

	local i = nodePosition - 1
	local currNode = node
	while i >= 0 do
		local point = line.geom:getPointN(i)
		local nodeId = point:asText()

		if graph[nodeId] then
			reviewExistingNode(graph[nodeId], currNode, i, line)
		else
			local previousNode = createNodeByNextPoint(point, i, currNode, line)
			graph[nodeId] = previousNode
			linkNodeToNext(previousNode, currNode)
			currNode = previousNode
		end

		i = i - 1
	end
end

local function addAllNodesOfLineForward(graph, line, node, nodePosition)
	if nodePosition == line.npoints - 1 then return end

	local currNode = node
	for i = nodePosition + 1, line.npoints - 1 do
		local point = line.geom:getPointN(i)
		local nodeId = point:asText()

		if nodeExists(graph[nodeId]) then
			reviewExistingNode(graph[nodeId], currNode, i, line)
		else
			local nextNode = createNodeByNextPoint(point, i, currNode, line)
			graph[nodeId] = nextNode
			linkNodeToNext(nextNode, currNode)
			currNode = nextNode
		end
	end
end

local function findSecondPointInEnds(firstNode, targetNode)
	local line = targetNode.line
	local pointInfo = {}

	if firstNode.pos == 0 then
		pointInfo.point = line.geom:getPointN(1)
		pointInfo.pos = 1
	else
		local npoints = line.npoints
		if firstNode.pos == npoints - 1 then
			pointInfo.point = line.geom:getPointN(npoints - 2)
			pointInfo.pos = npoints - 2
		end
	end

	return pointInfo
end

local function isTargetBetween(pTarget, pFirst, pOther)
	local xt = pTarget:getX()
	local xf = pFirst:getX()
	local xo = pOther:getX()

	if ((xo < xt) and (xt < xf)) or ((xo > xt) and (xt > xf)) then
		return true
	end

	return false
end

local function findSecondPointInInterior(firstNode, targetNode)
	local line = targetNode.line
	local pointInfo = {}
	local pAfter = line.geom:getPointN(firstNode.pos + 1)
	local pBefore = line.geom:getPointN(firstNode.pos - 1)

	if isTargetBetween(targetNode.point, firstNode.point, pAfter) then
		pointInfo.point = pAfter
		pointInfo.pos = firstNode.pos + 1
	else
		pointInfo.point = pBefore
		pointInfo.pos = firstNode.pos - 1
	end

	return pointInfo
end

local function findSecondPoint(firstNode, targetNode)
	local pointInfo = findSecondPointInEnds(firstNode, targetNode)

	local hasNotFound = not pointInfo.point
	if hasNotFound then
		pointInfo = findSecondPointInInterior(firstNode, targetNode)
	end

	pointInfo.distance = calculateFullDistance(targetNode, pointInfo.point, targetNode.line)

	return pointInfo
end

local function linkFirstAndSecondNodes(targetNode, firstNode, secNode)
	targetNode.first = firstNode
	targetNode.second = secNode
	firstNode.next = targetNode
	secNode.next = targetNode
end

local function addAllNodesOfTargetLines(graph, firstNode, targetNode)
	local line = targetNode.line
	local secPoint = findSecondPoint(firstNode, targetNode)
	local secNode = createNode(secPoint.point, secPoint.distance, line, secPoint.pos, targetNode.targetId)
	graph[secNode.id] = secNode

	linkFirstAndSecondNodes(targetNode, firstNode, graph[secNode.id])

	if firstNode.pos == 0 then
		addAllNodesOfLineForward(graph, line, graph[secNode.id], graph[secNode.id].pos)
	elseif firstNode.pos == line.npoints - 1 then
		addAllNodesOfLineBackward(graph, line, graph[secNode.id], graph[secNode.id].pos) -- TODO: move it up
	elseif secPoint.pos > firstNode.pos then
		addAllNodesOfLineForward(graph, line, graph[secNode.id], graph[secNode.id].pos)
		addAllNodesOfLineBackward(graph, line, firstNode, firstNode.pos)
	else
		addAllNodesOfLineForward(graph, line, firstNode, firstNode.pos)
		addAllNodesOfLineBackward(graph, line, graph[secNode.id], graph[secNode.id].pos)
	end
end

local function createFirstNode(targetNode)
	local firstPoint = findFirstPoint(targetNode)
	local totalDistance = targetNode.distance + firstPoint.distance
	return createNode(firstPoint.point, totalDistance, targetNode.line, firstPoint.pos, targetNode.targetId)
end

local function addFirstNodes(graph, node)
	local firstNode = createFirstNode(node)
	graph[firstNode.id] = firstNode

	addAllNodesOfTargetLines(graph, graph[firstNode.id], node)
end

local function copyGraphToNetpoints(netpoints, graph)
	forEachElement(graph, function(id, node)
		netpoints[id] = node
	end)
end

local function addNodesFromTargetLines(self)
	local graph = {}

	forEachElement(self.netpoints, function(id, node)
		graph[id] = node --< I don't want to change self.netpoints in this loop
		addFirstNodes(graph, node)
	end)

	copyGraphToNetpoints(self.netpoints, graph)
end

local function isNodeBelongingToTargetLine(node, targetLine)
	return node.line.id == targetLine.id
end

local function isTargetLine(line)
	return targetLines[line.id] ~= nil
end

local function addNodesForward(self, targetLine, point, line)
	local nid = point:asText()
	local node = self.netpoints[nid]

	if isNodeBelongingToTargetLine(node, targetLine) then
		addAllNodesOfLineForward(self.netpoints, line, node, 0)
		computedLines[line.id] = line
	end
end

local function addNodesBackward(self, targetLine, point, line)
	local nid = point:asText()
	local node = self.netpoints[nid]

	if isNodeBelongingToTargetLine(node, targetLine) then
		addAllNodesOfLineBackward(self.netpoints, line, node, line.npoints - 1)
		computedLines[line.id] = line
	end
end

local function isLineUncomputed(line)
	return not (isTargetLine(line) or computedLines[line.id])
end

local function isAdjacentByPointsConsideringError(p1, p2, error)
	return p1:distance(p2) <= error
end

local function findAdjacentLineAndAddItsPoints(self, line)
	local endpointsLine = {first = line.geom:getStartPoint(), last = line.geom:getEndPoint()}

	forEachElement(self.lines, function(_, adjacent)
		if isLineUncomputed(adjacent) then
			local endpointsAdjacent = {first = adjacent.geom:getStartPoint(), last = adjacent.geom:getEndPoint()}

			if isAdjacentByPointsConsideringError(endpointsLine.first, endpointsAdjacent.first, self.error) then
				addNodesForward(self, line, endpointsLine.first, adjacent)
			elseif isAdjacentByPointsConsideringError(endpointsLine.first, endpointsAdjacent.last, self.error) then
				addNodesBackward(self, line, endpointsLine.first, adjacent)
			elseif isAdjacentByPointsConsideringError(endpointsLine.last, endpointsAdjacent.first, self.error) then
				addNodesForward(self, line, endpointsLine.last, adjacent)
			elseif isAdjacentByPointsConsideringError(endpointsLine.last, endpointsAdjacent.last, self.error) then
				addNodesBackward(self, line, endpointsLine.last, adjacent)
			end
		end
	end)
end

local function addNodesFromAdjacentsToTargetLines(self)
	forEachElement(targetLines, function(_, targetLine)
		findAdjacentLineAndAddItsPoints(self, targetLine)
	end)
end

local function isLineAlreadyComputed(line)
	return computedLines[line.id] ~= nil
end

local function hasUncomputedLines(self)
	return getn(computedLines) + getn(targetLines) ~= getn(self.lines)
end

local function addNodesFromNonAdjacentsToTargetLines(self)
	forEachElement(self.lines, function(_, line)
		if isLineAlreadyComputed(line) then
			findAdjacentLineAndAddItsPoints(self, line)
		end
	end)

	if hasUncomputedLines(self) then
		addNodesFromNonAdjacentsToTargetLines(self)
	end
end

local function createConnectivityInfoGraph(self)
	addNodesFromTargetLines(self)
	addNodesFromAdjacentsToTargetLines(self)
	addNodesFromNonAdjacentsToTargetLines(self)
end

local function createOpenNetwork(self)
	inside = self.inside
	outside = self.outside
	self.linesCs = self.lines
	self.lines = createLinesInfo(self.lines)
	if self.validate then
		validateLines(self)
	end
	findAndAddTargetNodes(self)
	createConnectivityInfoGraph(self)
end

Network_ = {
	type_ = "Network"
}

metaTableNetwork_ = {
	__index = Network_
}

--- Type that represents a network. It uses a set of lines and a set of destinations
-- that will be the end points of the network. This type requires that the network
-- is fully connected, meaning that it is possible to
-- reach any line from any other line of the network.
-- Distances within and without the network are computed in different ways.
-- In this sense, the distances inside the network should be proportionally
-- shorter then the distances outside the network in order to allow the shortest
-- paths to be within the network. Tipically, using the Network
-- changes the representation from space to time, meaning that travelling within
-- the network is faster than outside.
-- A Network can then be used to create a GPM, using a set of origins.
-- @arg data.error As default, two lines are connected in the Network only if they share
-- exactly the same point. This argument allows two lines to be connected when there is a
-- maximum error in the distance up to the its value.
-- Therefore, the default value for this argument is zero.
-- @arg data.lines A base::CellularSpace with lines to create network. It can be for example a set of roads.
-- @arg data.outside User-defined function that converts the distance based on an
-- Euclidean distance to a distance in the geographical space. This function is
-- applied to enter and to leave the network, as well as to try to see whether
-- the distance without using the network is shorter than using the network.
-- If not set a function, will return the distance itself.
-- This function gets one argument with the distance in Eucldean space
-- and must return the distance in the geographical space.
-- @arg data.progress Optional boolean value indicating whether Network will print messages
-- while processing values. The default value is true.
-- @arg data.target A base::CellularSpace with the destinations of the network.
-- @arg data.inside User defined function that converts the distance based on
-- an Euclidean distance to a distance in the geographical space. This function
-- is applied to every path within the network.
-- If not set a function, will return the distance itself. Note that,
-- if the user does not use this argument neither outside function, the
-- paths will never use the network, as the distance within the network will always
-- be greater than the distance outside the network.
-- This function gets two arguments, the distance in Euclidean space and the
-- line, and must return the distance in the geographical space. This means
-- that it is possible to use properties from the lines such as paved or
-- non-paved roads.
-- @arg data.validate A boolean value that check if the lines is valid to build the Network.
-- It is recommended that the lines be validated once at least. The default value is true.
-- @usage import("gpm")
--
-- roads = CellularSpace{file = filePath("roads.shp", "gpm")}
-- communities = CellularSpace{file = filePath("communities.shp", "gpm")}
--
-- network = Network{
--     lines = roads,
--     target = communities,
--     progress = false,
--     inside = function(distance, cell)
--         if cell.STATUS == "paved" then
--             return distance / 5
--         else
--             return distance / 2
--         end
--     end,
--     outside = function(distance)
--         return distance * 2
--     end
-- }
function Network(data)
	verifyNamedTable(data)
	verifyUnnecessaryArguments(data, {"target", "lines", "inside", "outside", "error", "progress", "validate"})
	mandatoryTableArgument(data, "lines", "CellularSpace")

	if data.lines.geometry then
		local cell = data.lines:sample()

		if not string.find(cell.geom:getGeometryType(), "Line") then
			customError("Argument 'lines' should be composed by lines, got '"..cell.geom:getGeometryType().."'.")
		end
	elseif data.lines.geometry == false then
		customError("The CellularSpace in argument 'lines' must be loaded without using argument 'geometry'.")
	end

	mandatoryTableArgument(data, "target", "CellularSpace")
	mandatoryTableArgument(data, "inside", "function")
	mandatoryTableArgument(data, "outside", "function")

	if data.target.geometry == false then
		customError("The CellularSpace in argument 'target' must be loaded without using argument 'geometry'.")
	end

	defaultTableValue(data, "error", 0)
	defaultTableValue(data, "progress", true)
	defaultTableValue(data, "validate", true)

	targetLines = {}
	computedLines = {}

	createOpenNetwork(data)

	setmetatable(data, metaTableNetwork_)
	return data
end
