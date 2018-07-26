// Generated by CoffeeScript 2.3.1
(function() {
  window.hit_vertexshader_glsl = "\nprecision highp float;\nuniform mat4 modelViewMatrix;\nuniform mat4 projectionMatrix;\nuniform float eventtime;\n\nattribute vec3 position;\nattribute vec3 offset;\nattribute vec2 uv;\nattribute vec3 orientation;\nattribute vec3 color;\nattribute float amplitude;\nattribute float time;\nattribute float tot;\n\nvarying vec2 vUv;\nvarying vec4 vcol;\n\nvoid main() {\n\n  vUv  = uv;\n  vcol = vec4( color, 1.0 - 10.0 * position.x );\n\n  vec3 xprime = orientation; \n  vec3 yprime = normalize( vec3( 0.001, -xprime.z, xprime.y ) ) ;\n  vec3 zprime = normalize( cross( xprime, yprime ) ) ;\n\n  float aa = 1.0;\n\n  if (eventtime < 1e99) // really big value of eventtime means we are not animating, but showing the full event\n        {\n          if ( eventtime < time )       aa=0.0;\n          if ( eventtime > (time+tot) ) aa=0.0;\n        } \n                \n  vec3 p = aa * amplitude * 4.0 * position.x * xprime + aa*position.y * yprime + aa*position.z * zprime;\n\n  gl_Position = projectionMatrix * modelViewMatrix * vec4( offset+ p, 1.0 );\n}";

}).call(this);