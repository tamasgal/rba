window.hit_vertexshader_glsl = """

precision highp float;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform float eventtime;

attribute vec3 position;
attribute vec3 offset;
attribute vec2 uv;
attribute vec3 orientation;
attribute vec3 color;
attribute float amplitude;
attribute float time;
attribute float tot;

varying vec2 vUv;
varying vec4 vcol;

void main() {

  vUv  = uv;
  vcol = vec4( color, 1.0 - 10.0 * position.x );

  vec3 xprime = orientation; 
  vec3 yprime = normalize( vec3( 0.001, -xprime.z, xprime.y ) ) ;
  vec3 zprime = normalize( cross( xprime, yprime ) ) ;

  float aa = 1.0;

  if (eventtime < 1e99) // really big value of eventtime means we are not animating, but showing the full event
        {
          if ( eventtime < time )       aa=0.0;
          if ( eventtime > (time+tot) ) aa=0.0;
        } 
                
  vec3 p = aa * amplitude * 4.0 * position.x * xprime + aa*position.y * yprime + aa*position.z * zprime;

  gl_Position = projectionMatrix * modelViewMatrix * vec4( offset+ p, 1.0 );
}
"""
 
