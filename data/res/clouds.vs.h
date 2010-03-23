
const char data_sha_clouds_vs[] = ""
"uniform float time;\n"
"\n"
"attribute vec4 pos;\n"
"attribute vec2 data;\n"
"\n"
"varying vec2 Texcoord;\n"
"varying vec4 Color;\n"
"\n"
"void main()\n"
"{	\n"
"  float color = data.x;\n"
"  float speed = data.y;\n"
"\n"
"  float x_add = (1.0 - (mod(time,speed)/speed)) *2.0 - 0.2;\n"
"  vec4 ppos = pos;\n"
"\n"
"  Texcoord = ppos.zw;\n"
"  Color = vec4(color,color,color,1.0);\n"
"\n"
"  ppos.x += x_add;\n"
"\n"
"  gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vec4(ppos.xy,0.0,1.0);\n"
"}\n"
;
