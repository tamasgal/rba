window.vertexshader_glsl = """

precision highp float;
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

attribute vec3 position;
attribute vec3 offset;
attribute vec2 uv;
attribute vec3 orientation;

varying vec2 vUv;
varying vec3 vPos;
varying vec3 vNormal;

mat3 rotationMatrix(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  //0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  //0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c            //,0.0,
               // 0.0,                                0.0,                                0.0,                                1.0
               );
}


void main() {
  	vUv = uv;
  
  	
	float rot_angle = acos( orientation.y );
	
	mat3 R = (rot_angle == 0.0)? mat3(1.0) : rotationMatrix(  normalize( cross( orientation, vec3(0.0, 1.0, 0.0)) ) , rot_angle );


  	vNormal = normalize( R * position );
  
  vPos = (    modelViewMatrix * vec4( offset +  R * position , 1.0 )     ) .xyz;
  vec4 v = (    modelViewMatrix * vec4( offset +  R * position , 1.0 )     ) ;
  gl_Position = projectionMatrix * v;
}
"""
