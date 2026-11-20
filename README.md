# Gunlord

A portrait mobile crowd shooter. Design: [DESIGN.md](DESIGN.md). Research: [RESEARCH.md](RESEARCH.md).

**Play in the browser:** https://solutionsunity.github.io/gunlord/ (phones too).
**Android:** the signed APK from the latest [release](https://github.com/solutionsunity/gunlord/releases),
or from the latest [build run](https://github.com/solutionsunity/gunlord/actions/workflows/build.yml).
Every push to `main` rebuilds and redeploys both; a `v*` tag publishes a release.

Requires Godot 4.7.

First run: bake the crowd characters (generated, not committed). Without them
the game still runs, with placeholder capsules.

    godot --headless --path . --import
    godot --headless --path . -s tools/bake_crowd.gd

| Task | Command |
|---|---|
| Play in the editor | open `project.godot` in Godot 4.7 and press F5 |
| Balance probe (headless bots) | `godot --headless --path . -s tests/simulate.gd` |
| Engagement probe (where enemies die, boss time under fire) | `godot --headless --path . -s tests/engagement.gd` |
| CPU cost per frame (simulation and view) | `godot --headless --path . -s tests/frame_cost.gd` |
| Bake crowd characters to `assets/baked/` | `godot --headless --path . -s tools/bake_crowd.gd` |
| Model gallery to `build/gallery.png` | `xvfb-run godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tests/gallery.gd -- shoot 0.3` |
| Squad close-up at time T to `build/` | `xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/closeup.gd -- T` |
| Menu, every level's stage and the results screen to `build/` | `xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/screens.gd` |
| Render frames to `build/` | `xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/screenshot.gd` |
| Web build | `godot --headless --path . --export-release Web build/web/index.html`, then serve `build/web/` |

Controls: drag with a finger or the mouse, or use the arrow keys.

## Layout

- `src/content/`: data — weapons, lane objects, level timelines
- `src/sim/`: the deterministic simulation; `Battle` runs each tick
- `src/view/`: drawing and HUD; reads the simulation, never writes to it. `Crowd` is one batched draw; `Stage` is the static scene; `crowd.gdshader` plays baked animations
- `tools/`: the crowd baker and in-house weapon models
- `assets/third_party/`: CC0 and OFL packs with their licenses (see CREDITS.md); `assets/baked/`: baker output
- `tests/`: headless bots and the frame renderer

## License

Code and original assets: [Apache License 2.0](LICENSE), copyright 2026
Solutions Unity. Third-party packs keep their own licenses; see
[CREDITS.md](CREDITS.md) and [NOTICE](NOTICE).
