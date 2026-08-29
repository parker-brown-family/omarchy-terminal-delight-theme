-- Terminal Delight — curved glass.
--
-- Two layers, same idea as the app:
--   1. per-window frosted glass  (rounding + squircle + blur + depth)
--   2. the tube                  (full-screen barrel warp, crt-glass.frag)
--
-- Loaded by default.hypr.omarchy as `omarchy.current.theme.hyprland`, i.e.
-- after Omarchy's defaults and before your ~/.config/hypr/looknfeel.lua, so
-- anything you set there still wins.

local home = os.getenv("HOME")
local shader = home .. "/.local/state/omarchy/current/theme/crt-glass.frag"

-- Signal Green -> Cyan, the wordmark gradient.
local active_border_color = { colors = { "rgba(67F454ee)", "rgba(29E3EDee)" }, angle = 45 }
local inactive_border_color = "rgba(282E3255)" -- Panel line, kept faint: the border IS the focus signal

hl.config({
  general = {
    border_size = 3,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    -- Curved corners. rounding_power > 2 is a squircle, which reads as blown
    -- glass rather than a rounded rectangle.
    rounding = 14,
    rounding_power = 2.6,

    -- Windows must be translucent for the blur behind them to be visible.
    active_opacity = 0.94,
    inactive_opacity = 0.86,

    dim_inactive = true,
    -- deep enough that the powered tile is unmistakable in a wall of tubes
    dim_strength = 0.28,

    blur = {
      enabled = true,
      size = 5,
      passes = 2,
      noise = 0.015,
      contrast = 1.05,
      brightness = 0.85,
      vibrancy = 0.18,
      popups = true,
    },

    shadow = {
      enabled = true,
      range = 26,
      render_power = 3,
      color = "rgba(00000066)",
    },

    -- The tube.
    screen_shader = shader,
  },
})

-- Per-window curved glass lives in ~/.config/hypr/shaders/{surface,ext}.frag
-- (loaded once at Hyprland startup; the warp only compiles into the
-- rounded-window shader variant, so it keys off rounding > 0 above).
-- Terminal Delight warps its own panes internally -- rounding 0 exempts the
-- app from the compositor's warp so panes aren't bent twice.
o.window("terminal-delight", { rounding = 0 })
