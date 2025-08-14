"""
    
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments

"""

from time import perf_counter
from random import randint

import pygame
import imgui

from src.common import WINDOW_WIDTH, WINDOW_HEIGHT, TARGET_FPS
from src.gui import ImguiPygameModernGLAbomination
from src.engine import RadianceCascadesEngine


if __name__ == "__main__":
    pygame.display.set_mode(
        (WINDOW_WIDTH, WINDOW_HEIGHT),
        pygame.OPENGL | pygame.DOUBLEBUF
    )
    clock = pygame.time.Clock()

    engine = RadianceCascadesEngine((WINDOW_WIDTH, WINDOW_HEIGHT))
    engine.stage = 4

    gui_helper = ImguiPygameModernGLAbomination((WINDOW_WIDTH, WINDOW_HEIGHT), engine._context)

    color_canvas = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT), pygame.SRCALPHA).convert_alpha()
    emissive_canvas = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT), pygame.SRCALPHA).convert_alpha()
    last_mouse = pygame.Vector2()
    brush_radius = 10.0
    brush_radiush = brush_radius * 0.5
    hue = 0

    for i in range(100):
        diffuse_color = (randint(0, 255), randint(0, 255), randint(0, 255))
        pos = (randint(0, WINDOW_WIDTH), randint(0, WINDOW_HEIGHT))
        radius = randint(1, 50)

        pygame.draw.circle(color_canvas, diffuse_color, pos, radius)

        if randint(0, 1) == 0:
            pygame.draw.circle(emissive_canvas, (0, 0, 0, 255), pos, radius)

    is_running = True
    frame = 0
    while is_running:
        clock.tick(TARGET_FPS)

        events = pygame.event.get()
        for event in events:
            if event.type == pygame.QUIT:
                is_running = False

            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    is_running = False

                elif event.key == pygame.K_c:
                    color_canvas.fill((0, 0, 0, 0))
                    emissive_canvas.fill((0, 0, 0, 0))
        
        gui_helper.process_events(events)

        mouse = pygame.Vector2(*pygame.mouse.get_pos())

        if not gui_helper.io.want_capture_mouse and any(pygame.mouse.get_pressed()):
            if pygame.mouse.get_pressed()[0]:
                color = (255, 0, 0)
                emissive = False

            elif pygame.mouse.get_pressed()[2]:
                color = (255, 255, 255)
                emissive = True

            elif pygame.mouse.get_pressed()[1]:
                hue += 1
                color = pygame.Color.from_hsva(hue % 360, 100, 100, 100)
                emissive = True

            delta = last_mouse - mouse
            if delta.length() > 0.3:
                dir = delta.normalize()

                points = (
                    mouse + dir.rotate(90) * brush_radiush,
                    last_mouse + dir.rotate(90) * brush_radiush,
                    last_mouse - dir.rotate(90) * brush_radiush,
                    mouse - dir.rotate(90) * brush_radiush
                )

                pygame.draw.polygon(color_canvas, color, points, 0)
                pygame.draw.circle(color_canvas, color, mouse, brush_radiush)
                pygame.draw.circle(color_canvas, color, last_mouse, brush_radiush)

                if emissive:
                    e = 255
                    pygame.draw.polygon(emissive_canvas, (0, 0, 0, e), points, 0)
                    pygame.draw.circle(emissive_canvas, (0, 0, 0, e), mouse, brush_radiush)
                    pygame.draw.circle(emissive_canvas, (0, 0, 0, e), last_mouse, brush_radiush)
        
        last_mouse = mouse.copy()

        _start = perf_counter()

        engine.update_color_scene(color_canvas)
        engine.update_emissive_scene(emissive_canvas)
        engine.render()

        imgui.new_frame()

        imgui.begin("Settings", True, flags=imgui.WINDOW_NO_MOVE | imgui.WINDOW_ALWAYS_AUTO_RESIZE)
        imgui.set_window_position(0, 0)
        imgui.set_window_size(245, 250)
        
        imgui.push_item_width(imgui.get_window_width() * 0.5)
        _, brush_radius = imgui.slider_float("Brush radius", brush_radius, 1.0, 100.0, format="%.1f")
        brush_radiush = brush_radius * 0.5

        stage_name = ("Painting", "JFA", "Distance Field", "Pathtracing GI")[engine.stage-1]
        _, engine.stage = imgui.slider_int(f"Rendering stage", engine.stage, 1, 4, format=stage_name)

        _, engine.jfa_passes = imgui.slider_int("JFA passes", engine.jfa_passes, 1, 12, format="%d")

        _, engine._pt_program["u_ray_count"] = imgui.slider_int("Ray count", engine._pt_program["u_ray_count"].value, 4, 80, format="%d")

        noise_name = ("None", "Mulberry32", "Bluenoise")[engine._pt_program["u_noise_method"].value]
        _, engine._pt_program["u_noise_method"] = imgui.slider_int("Noise method", engine._pt_program["u_noise_method"].value, 0, 2, format=noise_name)

        if imgui.tree_node("Post-processing", imgui.TREE_NODE_DEFAULT_OPEN):
            _, engine._display_program["u_enable_post"] = imgui.checkbox("Enable post-processing", engine._display_program["u_enable_post"].value)
            _, engine._display_program["u_exposure"] = imgui.slider_float("Exposure", engine._display_program["u_exposure"].value, -5.0, 5.0, format="%.1f")

            tm_name = ("None", "ACES Filmic")[engine._display_program["u_tonemapper"].value]
            _, engine._display_program["u_tonemapper"] = imgui.slider_int(f"Tonemapper", engine._display_program["u_tonemapper"].value, 0, 1, format=tm_name)
            
            imgui.tree_pop()

        if imgui.tree_node("Controls"):
            imgui.push_text_wrap_pos(0.0)
            imgui.text("- [ESC] to quit the application.")
            imgui.text("- [Left MB] for diffuse material brush.")
            imgui.text("- [Right MB] for emissive material brush.")
            imgui.text("- [Middle MB] for rainbow emissive material brush.")
            imgui.text("- [C] to clear canvas.")
            imgui.pop_text_wrap_pos()
            imgui.tree_pop()

        imgui.end()
        
        imgui.render()

        gui_helper.render(imgui.get_draw_data())

        pygame.display.flip()

        elapsed = perf_counter() - _start
        pygame.display.set_caption(f"Radiance Cascades Experiments  -  {round(clock.get_fps())}fps  render time: {round(elapsed*1000, 2)}ms")

        frame += 1
        if frame % 60 == 0:
            print(f"{round(clock.get_fps())}fps render time: {round(elapsed*1000, 2)}ms")

    pygame.quit()
    gui_helper.cleanup()