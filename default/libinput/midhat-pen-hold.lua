-- Mid’hat: hold the pen still to right-click (midhat-pen-hold-guard links it in).
-- A landing tip is held back. Lifting it, or moving it more than 1.5 mm,
-- within 0.6 s lets it through as a normal touch starting where the tip
-- landed; staying still that long
-- sends a right-click (BTN_STYLUS2) and ignores the rest of that touch.
-- libinput 1.32 takes tablet pressure from the kernel, not from plugin frames,
-- so pressure is switched off and contact follows BTN_TOUCH alone.

libinput:register({ 1 })

local HOLD_US = 600 * 1000
local MOVE_MM = 1.5
local PANEL_MM = { x = 166, y = 266 }

local pen
local state = "idle"
local x, y, x0, y0 = 0, 0, 0, 0
local reach_x, reach_y = 1, 1

local function without_touch(events)
    local kept = {}
    for _, e in ipairs(events) do
        if e.usage ~= evdev.BTN_TOUCH then
            table.insert(kept, e)
        end
    end
    return kept
end

local function moved()
    local dx, dy = (x - x0) / reach_x, (y - y0) / reach_y
    return dx * dx + dy * dy > 1
end

local function on_frame(device, events, time)
    local touch, gone
    for _, e in ipairs(events) do
        if e.usage == evdev.ABS_X then
            x = e.value
        elseif e.usage == evdev.ABS_Y then
            y = e.value
        elseif e.usage == evdev.BTN_TOUCH then
            touch = e.value
        elseif e.usage == evdev.BTN_TOOL_PEN and e.value == 0 then
            gone = true
        end
    end
    local up = touch == 0 or gone

    if state == "idle" then
        if touch == 1 then
            state, x0, y0 = "holding", x, y
            libinput:timer_set_absolute(time + HOLD_US)
            return without_touch(events)
        end
    elseif state == "holding" then
        if up then
            libinput:timer_cancel()
            state = "idle"
            device:prepend_frame({ { usage = evdev.BTN_TOUCH, value = 1 } })
        elseif moved() then
            libinput:timer_cancel()
            state = "passing"
            device:prepend_frame({
                { usage = evdev.ABS_X, value = x0 },
                { usage = evdev.ABS_Y, value = y0 },
                { usage = evdev.BTN_TOUCH, value = 1 },
            })
            return events
        end
    elseif state == "passing" then
        if up then
            state = "idle"
        end
    elseif state == "ignoring" then
        if up then
            state = "idle"
            return without_touch(events)
        end
    end
    return nil
end

libinput:connect("timer-expired", function()
    if state ~= "holding" or not pen then
        return
    end
    state = "ignoring"
    pen:append_frame({ { usage = evdev.BTN_STYLUS2, value = 1 } })
    pen:append_frame({ { usage = evdev.BTN_STYLUS2, value = 0 } })
end)

libinput:connect("new-evdev-device", function(device)
    if device:name() ~= "himax-stylus" then
        return
    end
    local abs = device:absinfos()
    local ax, ay = abs[evdev.ABS_X], abs[evdev.ABS_Y]
    if not (ax and ay and device:usages()[evdev.BTN_STYLUS2]) then
        return
    end
    reach_x = MOVE_MM * (ax.maximum - ax.minimum) / PANEL_MM.x
    reach_y = MOVE_MM * (ay.maximum - ay.minimum) / PANEL_MM.y
    device:disable_evdev_usage(evdev.ABS_PRESSURE)
    pen, state = device, "idle"
    device:connect("evdev-frame", on_frame)
    device:connect("device-removed", function()
        libinput:timer_cancel()
        pen, state = nil, "idle"
    end)
    libinput:log_info(string.format("midhat-pen-hold: %s, %.0f x %.0f units = %.1f mm",
        device:name(), reach_x, reach_y, MOVE_MM))
end)
