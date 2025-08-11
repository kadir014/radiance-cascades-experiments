from array import array
from math import ceil, log2, pow

import pygame
import moderngl


class RadianceCascadesEngine:
    def __init__(self, resolution: tuple[int, int]) -> None:
        """
        Parameters
        ----------
        resolution
            Resolution in pixels.
        """

        self.resolution = resolution
        self._context = moderngl.create_context()

        base_vertex_shader = """
        #version 330

        in vec2 in_position;
        in vec2 in_uv;

        out vec2 v_uv;

        void main() {
            gl_Position = vec4(in_position, 0.0, 1.0);

            v_uv = in_uv;
        }
        """

        # All VAOs will use the same buffers since they are all just plain screen quads
        #self._vbo = self.create_buffer_object([-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0])
        self._vbo = self.create_buffer_object([-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0])
        self._uvbo = self.create_buffer_object([0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0])
        self._ibo = self.create_buffer_object([0, 1, 2, 1, 2, 3])

        self._display_program = self._context.program(
            vertex_shader=base_vertex_shader,
            fragment_shader=open("src/shaders/display.fsh").read()
        )

        self._display_vao = self._context.vertex_array(
            self._display_program,
            (
                (self._vbo, "2f", "in_position"),
                (self._uvbo, "2f", "in_uv")
            ),
            self._ibo
        )

        self._seed_program = self._context.program(
            vertex_shader=base_vertex_shader,
            fragment_shader=open("src/shaders/uv_seed.fsh").read()
        )

        self._seed_vao = self._context.vertex_array(
            self._seed_program,
            (
                (self._vbo, "2f", "in_position"),
                (self._uvbo, "2f", "in_uv")
            ),
            self._ibo
        )

        self._jfa_program = self._context.program(
            vertex_shader=base_vertex_shader,
            fragment_shader=open("src/shaders/jfa.fsh").read()
        )

        self._jfa_program["u_invresolution"] = 1.0 / self.resolution[0], 1.0 / self.resolution[1]

        self._jfa_vao = self._context.vertex_array(
            self._jfa_program,
            (
                (self._vbo, "2f", "in_position"),
                (self._uvbo, "2f", "in_uv")
            ),
            self._ibo
        )

        self._df_program = self._context.program(
            vertex_shader=base_vertex_shader,
            fragment_shader=open("src/shaders/df.fsh").read()
        )

        self._df_vao = self._context.vertex_array(
            self._df_program,
            (
                (self._vbo, "2f", "in_position"),
                (self._uvbo, "2f", "in_uv")
            ),
            self._ibo
        )

        self._pt_program = self._context.program(
            vertex_shader=base_vertex_shader,
            fragment_shader=open("src/shaders/pathtracer.fsh").read()
        )

        self._pt_program["s_scene"] = 0
        self._pt_program["s_df"] = 1

        self._pt_vao = self._context.vertex_array(
            self._pt_program,
            (
                (self._vbo, "2f", "in_position"),
                (self._uvbo, "2f", "in_uv")
            ),
            self._ibo
        )

        self.scene_texture = self._context.texture(self.resolution, 4)
        self.scene_texture.filter = (moderngl.NEAREST, moderngl.NEAREST)

        self.stage = 1
        self.jfa_passes = 1

        self._jfa_target0 = self._context.texture(self.resolution, 3, dtype="f4")
        self._jfa_target1 = self._context.texture(self.resolution, 3, dtype="f4")
        self._jfa_target0.filter = (moderngl.NEAREST, moderngl.NEAREST)
        self._jfa_target1.filter = (moderngl.NEAREST, moderngl.NEAREST)

        self._jfa_fbo0 = self._context.framebuffer(color_attachments=(self._jfa_target0,))
        self._jfa_fbo1 = self._context.framebuffer(color_attachments=(self._jfa_target1,))

        self._jfa_output = None

        self._df_target = self._context.texture(self.resolution, 3, dtype="f4")
        self._df_target.filter = (moderngl.NEAREST, moderngl.NEAREST)
        self._df_fbo = self._context.framebuffer(color_attachments=(self._df_target,))

        self._pt_target = self._context.texture(self.resolution, 3, dtype="f4")
        self._pt_target.filter = (moderngl.NEAREST, moderngl.NEAREST)
        self._pt_fbo = self._context.framebuffer(color_attachments=(self._pt_target,))

    def __del__(self) -> None:
        self._context.release()

    def create_buffer_object(self, data: list) -> moderngl.Buffer:
        """ Create buffer object from array. """

        dtype = "f" if isinstance(data[0], float) else "I"
        return self._context.buffer(array(dtype, data))
    
    def update_scene_texture(self, surface: pygame.Surface) -> None:
        """ Update scene texture. """
        
        self.scene_texture.write(pygame.image.tobytes(surface, "RGBA", True))
    
    def render(self) -> None:
        """ Render one frame. """

        self._context.screen.use()
        self._context.clear(0.0, 0.0, 0.0)

        if self.stage == 1:
            self._context.screen.use()
            self.scene_texture.use()
            self._display_vao.render()

        elif self.stage == 2:
            self._jfa(cap_passes=True)
            self._context.screen.use()
            self._jfa_output.use()
            self._display_vao.render()

        elif self.stage == 3:
            self._df()
            self._context.screen.use()
            self._df_target.use()
            self._display_vao.render()

        elif self.stage == 4:
            self._df()
            self._pt_fbo.use()
            self.scene_texture.use(0)
            self._df_target.use(1)
            self._pt_vao.render()
            self._context.screen.use()
            self._pt_target.use()
            self._display_vao.render()

    def _jfa(self, cap_passes: bool = False) -> None:
        """ Jump Fill Algorithm. """

        self._jfa_fbo0.clear(0.0, 0.0, 0.0)
        self._jfa_fbo1.clear(0.0, 0.0, 0.0)

        self._jfa_fbo0.use()
        self.scene_texture.use()
        self._seed_vao.render()

        if cap_passes:
            passes = self.jfa_passes
        else:
            passes = ceil(log2(max(self.resolution[0], self.resolution[1])))

        targets = (self._jfa_target0, self._jfa_target1)
        fbos = (self._jfa_fbo1, self._jfa_fbo0)

        for i in range(passes):
            a = i % 2
            b = (i + 1) % 2
            current_target = targets[a]
            current_fbo = fbos[a]

            current_fbo.use()
            current_target.use()
            off = pow(2.0, passes - i - 1)
            # TODO: Offset look-up-table
            self._jfa_program["u_offset"] = off
            self._jfa_vao.render()

            self._jfa_output = targets[b]

    def _df(self) -> None:
        """ Generate from JFA texture. """

        self._jfa()

        self._df_fbo.use()
        self._jfa_output.use()
        self._df_vao.render()