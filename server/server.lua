local VALID_PAYMENT_TYPES = {
    cash = true,
    bank = true
}

local itemPriceCache = nil

local function buildItemPriceCache()
    local cache = {}

    for _, shop in pairs(Config.Shops or {}) do
        for _, category in pairs(shop.categories or {}) do
            for _, item in pairs(category.items or {}) do
                if item.name and item.perPrice then
                    cache[item.name] = tonumber(item.perPrice)
                end
            end
        end
    end

    return cache
end

local function getItemPrices()
    if not itemPriceCache then
        itemPriceCache = buildItemPriceCache()
    end

    return itemPriceCache
end

local function sanitizeBasket(basket)
    if type(basket) ~= "table" then
        return nil
    end

    local sanitizedBasket = {}

    for _, entry in pairs(basket) do
        if type(entry) == "table" and type(entry.name) == "string" then
            local amount = math.floor(tonumber(entry.amount) or 0)
            if amount > 0 then
                sanitizedBasket[entry.name] = (sanitizedBasket[entry.name] or 0) + amount
            end
        end
    end

    return sanitizedBasket
end

local function calculateServerTotal(sanitizedBasket)
    local prices = getItemPrices()
    local total = 0

    for itemName, amount in pairs(sanitizedBasket) do
        local unitPrice = prices[itemName]
        if not unitPrice then
            return nil
        end

        total = total + (unitPrice * amount)
    end

    return total
end

RegisterNetEvent('exter-shop:makePayment', function(paymentType, clientTotal, basket)
    local src = source

    if not VALID_PAYMENT_TYPES[paymentType] then
        return
    end

    local player = GetPlayer(src)
    if not player then
        return
    end

    local sanitizedBasket = sanitizeBasket(basket)
    if not sanitizedBasket or next(sanitizedBasket) == nil then
        Notify(src, Config.Notify.error, 5000, 'error')
        return
    end

    local serverTotal = calculateServerTotal(sanitizedBasket)
    if not serverTotal or serverTotal <= 0 then
        Notify(src, Config.Notify.error, 5000, 'error')
        return
    end

    local normalizedClientTotal = tonumber(clientTotal) or 0
    if normalizedClientTotal > 0 and normalizedClientTotal ~= serverTotal then
        print(("[exter-shop] Price mismatch prevented for player %s (client=%s, server=%s)"):format(src, normalizedClientTotal, serverTotal))
    end

    local playerMoney = tonumber(GetPlayerMoney(src, paymentType)) or 0
    if playerMoney < serverTotal then
        Notify(src, Config.Notify.error, 5000, 'error')
        return
    end

    RemoveMoney(src, paymentType, serverTotal)

    for itemName, amount in pairs(sanitizedBasket) do
        AddItem(src, itemName, amount)
    end

    Notify(src, Config.Notify.success, 5000, 'success')
end)
