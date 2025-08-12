"""
    
    Radiance Cascades Experiments
    https://github.com/kadir014/radiance-cascades-experiments

"""

from time import perf_counter

import pygame
import imgui

from src.common import WINDOW_WIDTH, WINDOW_HEIGHT, TARGET_FPS
from src.gui import ImguiPygameModernGLAbomination
from src.engine import RadianceCascadesEngine


if __name__ == "__main__":
    window = pygame.display.set_mode(
        (WINDOW_WIDTH, WINDOW_HEIGHT),
        pygame.OPENGL | pygame.DOUBLEBUF
    )
    clock = pygame.time.Clock()

    engine = RadianceCascadesEngine((WINDOW_WIDTH, WINDOW_HEIGHT))

    gui_helper = ImguiPygameModernGLAbomination((WINDOW_WIDTH, WINDOW_HEIGHT), engine._context)

    canvas = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT), pygame.SRCALPHA).convert_alpha()
    last_mouse = pygame.Vector2()
    brush_radius = 10.0
    brush_radiush = brush_radius * 0.5
    brush_color = (255, 255, 255)
    hue = 0

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
        
        gui_helper.process_events(events)

        mouse = pygame.Vector2(*pygame.mouse.get_pos())

        if not gui_helper.io.want_capture_mouse and any(pygame.mouse.get_pressed()):
            if pygame.mouse.get_pressed()[0]: color = brush_color
            elif pygame.mouse.get_pressed()[2]: color = (0, 0, 0)
            elif pygame.mouse.get_pressed()[1]:
                hue += 1
                color = pygame.Color.from_hsva(hue % 360, 100, 100, 100)

            delta = last_mouse - mouse
            if delta.length() > 0.3:
                dir = delta.normalize()

                points = (
                    mouse + dir.rotate(90) * brush_radiush,
                    last_mouse + dir.rotate(90) * brush_radiush,
                    last_mouse - dir.rotate(90) * brush_radiush,
                    mouse - dir.rotate(90) * brush_radiush
                )
                pygame.draw.polygon(canvas, color, points, 0)

                pygame.draw.circle(canvas, color, mouse, brush_radiush)
                pygame.draw.circle(canvas, color, last_mouse, brush_radiush)
        
        last_mouse = mouse.copy()

        _start = perf_counter()

        engine.update_scene_texture(canvas)
        engine.render()

        imgui.new_frame()

        imgui.begin("Settings", True)
        imgui.set_window_position(0, 0)
        imgui.set_window_size(240, 100)
        
        imgui.push_item_width(imgui.get_window_width() * 0.5)
        _, brush_radius = imgui.slider_float("Brush radius", brush_radius, 1.0, 30.0, format="%.1f")
        brush_radiush = brush_radius * 0.5

        stage_name = ("Painting", "JFA", "Distance Field", "Pathtracing GI")[engine.stage-1]
        _, engine.stage = imgui.slider_int(f"Rendering stage", engine.stage, 1, 4, format=f"{stage_name}")

        _, engine.jfa_passes = imgui.slider_int("JFA passes", engine.jfa_passes, 1, 12, format="%d")

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