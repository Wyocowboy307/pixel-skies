extends RefCounted
func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    await cap.wait(0.4)
    var root: Window = cap.get_tree().root
    print("[probe] root.theme = ", root.theme)
    var hud: Control = main.get_node("UI/Hud")
    print("[probe] hud.theme = ", hud.theme)
    for child: Node in hud.get_children():
        if child is PanelContainer:
            var sb: StyleBox = (child as PanelContainer).get_theme_stylebox("panel")
            print("[probe] hud panel stylebox = ", sb)
            print("[probe] is texture = ", sb is StyleBoxTexture)
            break
    print("[probe] project gui theme = ", ProjectSettings.get_setting("gui/theme/custom", "(unset)"))
