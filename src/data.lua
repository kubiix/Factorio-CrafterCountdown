data:extend({
    {
      type = "shortcut",
      name = "cc-toggle",
      order = "b[blueprints]-i[cc-toggle]",
      action = "lua",
      toggleable = true,
      associated_control_input = "cc-toggle",
      style = "default",
      icon = "__crafter-countdown__/graphics/shortcut.png",
      icon_size = 64,
      small_icon = "__crafter-countdown__/graphics/shortcut.png",
      small_icon_size = 64
    },
    {
        type = "custom-input",
        name = "cc-toggle",
        key_sequence = "CONTROL + L",
        consuming = "none"
      }
  })