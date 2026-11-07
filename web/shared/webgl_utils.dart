import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Compiles and links a WebGL program from vertex and fragment shader sources.
web.WebGLProgram? compileProgram(
  web.WebGL2RenderingContext gl,
  String vertSrc,
  String fragSrc,
) {
  final vs = compileShader(
    gl,
    web.WebGLRenderingContext.VERTEX_SHADER,
    vertSrc,
  );
  final fs = compileShader(
    gl,
    web.WebGLRenderingContext.FRAGMENT_SHADER,
    fragSrc,
  );
  if (vs == null || fs == null) return null;

  final prog = gl.createProgram();
  if (prog == null) return null;
  gl.attachShader(prog, vs);
  gl.attachShader(prog, fs);
  gl.linkProgram(prog);
  gl.detachShader(prog, vs);
  gl.detachShader(prog, fs);
  gl.deleteShader(vs);
  gl.deleteShader(fs);
  final ok =
      (gl.getProgramParameter(
        prog,
        web.WebGLRenderingContext.LINK_STATUS,
      ) as JSBoolean?)?.toDart ??
      false;
  if (!ok) {
    gl.deleteProgram(prog);
    return null;
  }
  return prog;
}

/// Compiles an individual WebGL vertex or fragment shader from source.
web.WebGLShader? compileShader(
  web.WebGL2RenderingContext gl,
  int type,
  String src,
) {
  final shader = gl.createShader(type);
  if (shader == null) return null;
  gl.shaderSource(shader, src);
  gl.compileShader(shader);
  final ok =
      (gl.getShaderParameter(
        shader,
        web.WebGLRenderingContext.COMPILE_STATUS,
      ) as JSBoolean?)?.toDart ??
      false;
  if (!ok) {
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}
