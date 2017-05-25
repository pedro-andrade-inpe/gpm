local roads = CellularSpace{
	file = filePath("roads.shp", "gpm"),
	geometry = true
}

local communities = CellularSpace{
	file = filePath("communities.shp", "gpm"),
	geometry = true
}

local network = Network{
	lines = roads,
	target = communities,
	progress = false,
	weight = function(distance, cell)
		if cell.STATUS == "paved" then
			return distance / 5
		else
			return distance / 2
		end
	end,
	outside = function(distance) return distance * 2 end
}

return {
	GPM = function(unitTest)
		local farms = CellularSpace{
			file = filePath("test/farms_cells.shp", "gpm"),
			geometry = true
		}

		local error_func = function()
			GPM{
				network = 2,
				origin = farms
			}
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("network", "Network", 2))

		farms = CellularSpace{
			file = filePath("farms.shp", "gpm")
		}

		error_func = function()
			GPM{
				network = network,
				origin = farms
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'origin' must be loaded with 'geometry = true'.")

		farms = CellularSpace{
			file = filePath("farms.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				network = network,
				origin = 2
			}
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("origin", "CellularSpace", 2))

		error_func = function()
			GPM{
				network = network,
				origin = farms,
				destination = farms
			}
		end
		unitTest:assertError(error_func, "It is nos possible to use 'destination' and 'network' arguments together.")

		error_func = function()
			GPM{
				origin = farms,
				destination = farms
			}
		end
		unitTest:assertError(error_func, "Could not infer value for mandatory argument 'strategy'.")


		error_func = function()
			GPM{
				origin = farms,
				distance = "distance"
			}
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("distance", "number", "distance"))

		error_func = function()
			GPM{
				origin = farms,
				distance = 100,
				destination = 2
			}
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("destination", "CellularSpace", 2))

		local polygons = CellularSpace{
			file = filePath("farms.shp", "gpm")
		}

		error_func = function()
			GPM{
				origin = farms,
				distance = 100,
				destination = polygons
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'destination' must be loaded with 'geometry = true'.")

		polygons = CellularSpace{
			file = filePath("farms.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = 2,
				strategy = "border"
			}
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("origin", "CellularSpace", 2))

		local farmsNeighbor = CellularSpace{
			file = filePath("roads.shp", "gpm")
		}

		error_func = function()
			GPM{
				origin = farmsNeighbor,
				strategy = "border"
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'origin' must be loaded with 'geometry = true'.")

		farmsNeighbor = CellularSpace{
			file = filePath("roads.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = farmsNeighbor,
				strategy = "border"
			}
		end
		unitTest:assertError(error_func, "Argument 'origin' should be composed by 'MultiPolygon', got 'MultiLineString'.")

		farmsNeighbor = CellularSpace{
			file = filePath("partofbrazil.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = farms,
				strategy = "distance",
				destination = "distance"
			}
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("destination", "CellularSpace", "distance"))

		local farmsPolygon = CellularSpace{
			file = filePath("roads.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = farms,
				strategy = "area",
				destination = farmsPolygon
			}
		end
		unitTest:assertError(error_func, "Argument 'destination' should be composed by 'MultiPolygon', got 'MultiLineString'.")

		error_func = function()
			GPM{
				strategy = "contains",
				destination = farmsPolygon
			}
		end
		unitTest:assertError(error_func, mandatoryArgumentMsg("origin"))

		error_func = function()
			GPM{
				origin = roads,
				strategy = "contains",
				destination = farmsPolygon
			}
		end
		unitTest:assertError(error_func, "Argument 'origin' should be composed by 'MultiPolygon', got 'MultiLineString'.")

		local farms_cells = CellularSpace{
			file = filePath("test/farms_cells.shp", "gpm")
		}

		error_func = function()
			GPM{
				origin = farms_cells,
				strategy = "contains",
				destination = farmsPolygon
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'origin' must be loaded with 'geometry = true'.")

		farms_cells = CellularSpace{
			file = filePath("test/farms_cells.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = farms_cells,
				strategy = "contains",
				destination = farmsPolygon
			}
		end
		unitTest:assertError(error_func, "Argument 'destination' should be composed by 'MultiPoint', got 'MultiLineString'.")

		farmsPolygon = CellularSpace{
			file = filePath("farms.shp", "gpm")
		}

		error_func = function()
			GPM{
				origin = farms_cells,
				strategy = "contains",
				destination = farmsPolygon
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'destination' must be loaded with 'geometry = true'.")

		communities = CellularSpace{
			file = filePath("communities.shp", "gpm")
		}

		communities = CellularSpace{
			file = filePath("farms.shp", "gpm"),
			geometry = true
		}

		farmsPolygon = CellularSpace{
			file = filePath("farms.shp", "gpm")
		}

		error_func = function()
			GPM{
				origin = farmsPolygon,
				strategy = "length",
				destination = farms_cells
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'origin' must be loaded with 'geometry = true'.")

		farms = CellularSpace{
			file = filePath("farms.shp", "gpm")
		}

		communities = CellularSpace{
			file = filePath("farms.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = communities,
				strategy = "length",
				destination = farms
			}
		end
		unitTest:assertError(error_func, "The CellularSpace in argument 'destination' must be loaded with 'geometry = true'.")

		farms = CellularSpace{
			file = filePath("farms.shp", "gpm"),
			geometry = true
		}

		local communitiesCs = CellularSpace{
			file = filePath("communities.shp", "gpm"),
			geometry = true
		}

		error_func = function()
			GPM{
				origin = farms,
				strategy = "length",
				destination = communitiesCs
			}
		end
		unitTest:assertError(error_func, "Argument 'destination' should be composed by 'MultiLineString', got 'MultiPoint'.")
	end,
	save = function(unitTest)
		local farms = CellularSpace{
			file = filePath("test/farms_cells.shp", "gpm"),
			geometry = true
		}

		local gpm = GPM{
			network = network,
			origin = farms,
			progress = false,
		}

		local nameFile = 2

		local error_func = function()
			gpm:save(nameFile)
		end
		unitTest:assertError(error_func, incompatibleTypeMsg("file", "string or File", nameFile))
	end
}
