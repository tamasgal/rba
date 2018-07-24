window.hit_fragmentshader_glsl = """

precision highp float;

varying vec2 vUv;
varying vec4 vcol;

void main() {

  if (vcol.a < 0.1 ) discard;
  gl_FragColor   = vcol ;

}
"""
