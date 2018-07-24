window.fragmentshader_glsl = """

precision highp float;
uniform sampler2D map;
varying vec2 vUv;


void main() {

  float mushroom_size = 0.23;
  float pmt_size      = 0.05;
  float ring_size     = 0.07;

  float p2 = pmt_size * pmt_size;
  float r2 = ring_size * ring_size;

  gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0 );

  float phi_prime = vUv.x;
  float theta     = vUv.y;
  float up        = 0.0; 

  if ( theta < 0.5  ) // force theta > 0.5
    {
      phi_prime += 1.0/12.0;
      theta = 1.0-theta;
      up = 100.0;
    }
  
  phi_prime = mod( phi_prime , 1./6. );
  if ( phi_prime > 1.0/12. ) phi_prime = 1.0/6. - phi_prime;

  float a = sin( theta * 3.1415 );
  a = a*a*4.0;
		

  float A = a*phi_prime * phi_prime;
  float B = a * (1.0/12.0 - phi_prime) *(1.0/12.0 - phi_prime) ;	  

  // the theta's of the dom positions are : 0.980875, 1.2706, 1.872738, 2.162463, 2.579597, 3.1415923073180982
 
  float d1 = (1.0-theta)* (1.0-theta);
  d1 = min( d1, up + A + ( theta-(2.579597/3.141592 ) ) *  ( theta-(2.579597/3.141592 ) ) );
  d1 = min (d1, B + ( theta-(2.16/3.141592 ) )     *  ( theta-(2.16/3.141592     ) ) );
  d1 = min( d1, A + ( theta-(1.872/3.141592    ) ) *  ( theta-(1.872/3.141592    ) ) );  

  if ( d1 < r2 ) gl_FragColor = vec4( 0.95, 0.8, 1.0, 1.0 );
  if ( d1 < p2 ) gl_FragColor = vec4( 0.9, 0.8, 0.0, 1.0 );

  if ( vUv.y < mushroom_size    )  gl_FragColor   = vec4( 0.7, 0.7, 0.7, 1.0 );

}
"""

window.fragmentshader_antares_glsl = """

precision highp float;
uniform sampler2D map;

varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vPos;

#include <common>
#include <bsdfs>
#include <lights_pars>

void main() {

  float pmt_size      = 0.20;
  float theta     = vUv.y;
  
  vec4 col;
  vec4 addedLights;
  
  if (theta < pmt_size) {
  col = vec4(1.0 , 0.85, 0.0 ,1.0);
  }
  else {
  col = vec4(0.1, 0.1, 0.0 , 1.0 );
  }
  
  
  for(int l = 0; l < NUM_POINT_LIGHTS; l++) {
    vec3 adjustedLight = pointLights[l].position;
    vec3 lightColor    = pointLights[l].color;
    vec3 lightDirection = normalize(vPos - adjustedLight);
    addedLights.rgb += clamp(   dot(-lightDirection, vNormal), 0.0, 0.8 ) * lightColor ;
    
  }
  
    gl_FragColor =  mix( col , addedLights, addedLights);
  
  
}
 """