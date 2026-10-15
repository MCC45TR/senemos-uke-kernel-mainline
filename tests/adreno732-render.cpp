// SPDX-License-Identifier: GPL-2.0-only
// Bounded native render/readback check; a software renderer must fail.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <gbm.h>
#include <libdrm/msm_drm.h>
#include <xf86drm.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <cerrno>
#include <iostream>
#include <stdexcept>

static void require(bool ok, const char *message) {
    if (!ok) throw std::runtime_error(message);
}
static GLuint shader(GLenum type, const char *source) {
    const GLuint object = glCreateShader(type);
    glShaderSource(object, 1, &source, nullptr);
    glCompileShader(object);
    GLint ok = 0;
    glGetShaderiv(object, GL_COMPILE_STATUS, &ok);
    require(ok, "Shader compilation failed");
    return object;
}
int main(int argc, char **argv) {
    try {
        require(argc == 2, "Usage: adreno732-render /dev/dri/renderD128");
        const int fd = open(argv[1], O_RDWR | O_CLOEXEC);
        require(fd >= 0, "Render node cannot be opened");
        drmVersionPtr version = drmGetVersion(fd);
        require(version && version->name && !std::strcmp(version->name, "msm"), "Wrong DRM driver");
        drmFreeVersion(version);
        drm_msm_param param = {};
        param.pipe = MSM_PIPE_3D0;
        param.param = MSM_PARAM_CHIP_ID;
        errno = 0;
        const int result = drmIoctl(fd, DRM_IOCTL_MSM_GET_PARAM, &param);
        std::cout << "chip=0x" << std::hex << param.value << " query=" << result << " errno=" << errno << std::endl;
        // MSM reports the speedbin in the upper 32 bits for newer GPUs.
        require(!result && static_cast<uint32_t>(param.value) == 0x43030b00,
                "Exact Adreno 732 chip ID not reported");
        gbm_device *gbm = gbm_create_device(fd);
        require(gbm, "GBM device creation failed");
        const auto get_display = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
            eglGetProcAddress("eglGetPlatformDisplayEXT"));
        require(get_display, "EGL platform display unavailable");
        EGLDisplay display = get_display(EGL_PLATFORM_GBM_KHR, gbm, nullptr);
        require(eglInitialize(display, nullptr, nullptr), "EGL initialization failed");
        require(eglBindAPI(EGL_OPENGL_ES_API), "GLES API unavailable");
        EGLConfig config;
        EGLint count = 0;
        const EGLint attributes[] = {EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE};
        require(eglChooseConfig(display, attributes, &config, 1, &count) && count == 1,
                "GLES configuration unavailable");
        const EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
        EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
        require(context != EGL_NO_CONTEXT &&
                eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, context), "GLES context failed");
        const char *renderer = reinterpret_cast<const char *>(glGetString(GL_RENDERER));
        require(renderer && (std::strstr(renderer, "Adreno") || !std::strncmp(renderer, "FD", 2)) &&
                !std::strstr(renderer, "llvmpipe") && !std::strstr(renderer, "softpipe"), "Software renderer rejected");
        std::cout << "chip=0x" << std::hex << param.value << " renderer=" << renderer << std::endl;
        GLuint texture, framebuffer;
        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 64, 64, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        require(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, "Framebuffer incomplete");
        const GLuint program = glCreateProgram();
        glAttachShader(program, shader(GL_VERTEX_SHADER, "attribute vec2 p; void main(){gl_Position=vec4(p,0.,1.);}"));
        glAttachShader(program, shader(GL_FRAGMENT_SHADER, "precision mediump float; void main(){gl_FragColor=vec4(.8,.2,.4,1.);}"));
        glBindAttribLocation(program, 0, "p");
        glLinkProgram(program);
        GLint linked = 0;
        glGetProgramiv(program, GL_LINK_STATUS, &linked);
        require(linked, "Shader link failed");
        glUseProgram(program);
        const GLfloat vertices[] = {-1, -1, 3, -1, -1, 3};
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, vertices);
        glEnableVertexAttribArray(0);
        glViewport(0, 0, 64, 64);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        GLubyte pixel[4] = {};
        glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
        require(glGetError() == GL_NO_ERROR && pixel[0] >= 203 && pixel[0] <= 205 &&
                pixel[1] >= 50 && pixel[1] <= 52 && pixel[2] >= 101 && pixel[2] <= 103 && pixel[3] == 255,
                "GPU pixel readback failed");
        std::cout << "64x64 shader draw and pixel readback passed" << std::endl;
        eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroyContext(display, context);
        eglTerminate(display);
        gbm_device_destroy(gbm);
        close(fd);
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << std::endl;
        return 1;
    }
}
