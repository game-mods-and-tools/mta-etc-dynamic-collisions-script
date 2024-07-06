function b_urshift(n, bs)
	return math.floor(n / math.pow(2, bs))
end
function b_lshift(n, bs)
	return n * math.pow(2, bs)
end
function fl(number)
	if number == 0 then
		return string.char(0, 0, 0, 0)
	elseif number ~= number then
		return string.char(0xff, 0xff, 0xff, 0xff)
	else
		local sign = 0x00
		if number < 0 then
			sign = 0x80
			number = -number
		end
		local mantissa, exponent = math.frexp(number)
		exponent = exponent + 0x7f
		if exponent <= 0 then
			mantissa = math.ldexp(mantissa, exponent - 1)
			exponent = 0
		elseif exponent > 0 then
			if exponent >= 0xff then
				return string.char(0x00, 0x00, 0x80, sign + 0x7f)
			elseif exponent == 1 then
				exponent = 0
			else
				mantissa = mantissa * 2 - 1
				exponent = exponent - 1
			end
		end
		mantissa = math.floor(math.ldexp(mantissa, 23) + 0.5)
		return string.char(
			mantissa % 0x100,
			math.floor(mantissa / 0x100) % 0x100,
			(exponent % 2) * 0x80 + math.floor(mantissa / 0x10000),
			sign + math.floor(exponent / 2)
		)
	end
end
function uint(n, sz)
	local data = ""
	for i = 1, sz do
		data = data .. string.char(b_urshift(n, 8 * (i - 1)) % 0x100)
	end
	return data
end
function ch(c, sz)
	return c .. string.rep(string.char(0), sz - string.len(c))
end
function t_vec(x, y, z)
	return fl(x) .. fl(y) .. fl(z)
end
function t_bounds(bl, tr, c, r)
	return fl(r)			 -- radius
		.. t_vec(unpack(c))  -- center
		.. t_vec(unpack(bl)) -- min
		.. t_vec(unpack(tr)) -- max
end
function t_surface()
	return uint(0, 8) -- material
		.. uint(0, 8) -- flag
		.. uint(0, 8) -- brightness
		.. uint(0, 8) -- light
end
function t_box(bl, tr)
	return t_vec(unpack(bl))
		.. t_vec(unpack(tr))
		.. t_surface()
end
function col_data(bl, tr)
	local header = ch("COLL", 4) -- magic bytes
		.. uint(64 + 20 + 28, 4) -- size of rest of file, does not seem to matter??
		.. ch("model_name", 22)	 -- model_name
		.. uint(0, 2)			 -- model id
		.. t_bounds(bl, tr, {0, 0, 0}, math.max(math.abs(bl[1] - tr[1]), math.abs(bl[2] - tr[2]), math.abs(bl[3] - tr[3])))

	local col_shapes = uint(0, 4) -- num spheres
		.. uint(0, 4)             -- num unknown
		.. uint(1, 4)             -- num boxes
		.. t_box(bl, tr)          -- the single col shape we're generating
		.. uint(0, 4)             -- num vertices
		.. uint(0, 4)             -- num faces

	return header .. col_shapes
end

function create_col_for(e)
	local x1, y1, z1, x2, y2, z2 = getElementBoundingBox(e)
	local xs, ys, zs = getObjectScale(e)
	-- could avoid loading the same col based on wanted sizes

	-- because we're creating a new model + collision for each element, the elements
	-- original collision is still there, so scaling smaller than the element results in
	-- the old collision still blocking things
	local col = engineLoadCOL(col_data({x1 * xs, y1 * ys, z1 * zs}, {x2 * xs, y2 * ys, z2 * zs}))
	local next_model_id = engineRequestModel("object")
	engineReplaceCOL(col, next_model_id)

	local obj = createObject(next_model_id, getElementPosition(e))
	setElementAlpha(obj, 0) -- hides the new object's model (trashcan default)
	setElementRotation(obj, getElementRotation(e))
end

addEventHandler("onClientResourceStart", resourceRoot, function()
	local es = getElementsByType("object")
	for _, e in ipairs(es) do
		if getElementModel(e) == 2933 then
			create_col_for(e)
		end
	end
end)