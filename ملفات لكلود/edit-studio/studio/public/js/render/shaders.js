const e=`
vec3 tetra(highp sampler3D lut, int n, vec3 c) {
  float s = float(n - 1);
  vec3 f = clamp(c, 0.0, 1.0) * s;
  ivec3 i0 = min(ivec3(f), ivec3(n - 2));
  vec3 d = f - vec3(i0);
  float x = d.r, y = d.g, z = d.b;
  vec3 c000 = texelFetch(lut, i0, 0).rgb;
  vec3 c111 = texelFetch(lut, i0 + ivec3(1, 1, 1), 0).rgb;
  vec3 a, b;
  float w0, w1, w2, w3;
  if (x > y) {
    if (y > z)      { a = texelFetch(lut, i0 + ivec3(1, 0, 0), 0).rgb; b = texelFetch(lut, i0 + ivec3(1, 1, 0), 0).rgb; w0 = 1.0 - x; w1 = x - y; w2 = y - z; w3 = z; }
    else if (x > z) { a = texelFetch(lut, i0 + ivec3(1, 0, 0), 0).rgb; b = texelFetch(lut, i0 + ivec3(1, 0, 1), 0).rgb; w0 = 1.0 - x; w1 = x - z; w2 = z - y; w3 = y; }
    else            { a = texelFetch(lut, i0 + ivec3(0, 0, 1), 0).rgb; b = texelFetch(lut, i0 + ivec3(1, 0, 1), 0).rgb; w0 = 1.0 - z; w1 = z - x; w2 = x - y; w3 = y; }
  } else {
    if (z > y)      { a = texelFetch(lut, i0 + ivec3(0, 0, 1), 0).rgb; b = texelFetch(lut, i0 + ivec3(0, 1, 1), 0).rgb; w0 = 1.0 - z; w1 = z - y; w2 = y - x; w3 = x; }
    else if (z > x) { a = texelFetch(lut, i0 + ivec3(0, 1, 0), 0).rgb; b = texelFetch(lut, i0 + ivec3(0, 1, 1), 0).rgb; w0 = 1.0 - y; w1 = y - z; w2 = z - x; w3 = x; }
    else            { a = texelFetch(lut, i0 + ivec3(0, 1, 0), 0).rgb; b = texelFetch(lut, i0 + ivec3(1, 1, 0), 0).rgb; w0 = 1.0 - y; w1 = y - x; w2 = x - z; w3 = z; }
  }
  return w0 * c000 + w1 * a + w2 * b + w3 * c111;
}
`,i=`
vec3 srgbEnc(vec3 x) {
  x = clamp(x, 0.0, 1.0);
  return mix(12.92 * x, 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), x));
}
vec3 apple709(vec3 v) { return srgbEnc(pow(clamp(v, 0.0, 1.0), vec3(1.961))); }
`,o=`#version 300 es
in vec2 aPos;
uniform mat3 uM;
uniform vec2 uFrame;
uniform vec2 uExpand;
uniform float uFlipY;
out vec2 vUV;
out vec2 vPos;
void main() {
  vec2 uv = aPos * (1.0 + 2.0 * uExpand) - uExpand;
  vec3 q = uM * vec3(uv, 1.0);
  vUV = uv;
  vPos = q.xy;
  vec2 c = vec2(q.x / uFrame.x * 2.0 - 1.0, 1.0 - q.y / uFrame.y * 2.0);
  if (uFlipY > 0.5) c.y = -c.y;
  gl_Position = vec4(c, 0.0, 1.0);
}
`,u=`#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
`,c=`#version 300 es
precision highp float;
in vec2 vPos;
uniform vec2 uFrame;
uniform vec4 uStops[8];
uniform int uNStops;
uniform vec4 uGlowA[8];
uniform vec4 uGlowB[8];
uniform int uNGlows;
uniform sampler2D uGrain;
uniform int uHasGrain;
uniform float uGrainOp;
uniform float uGrainTile;
out vec4 o;
void main() {
  float t = vPos.y / uFrame.y;
  vec3 c = vec3(0.0);
  if (uNStops > 0) {
    c = uStops[0].yzw;
    for (int i = 1; i < 8; i++) {
      if (i >= uNStops) break;
      vec4 a = uStops[i - 1], b = uStops[i];
      if (t > a.x) c = (t >= b.x) ? b.yzw : mix(a.yzw, b.yzw, (b.x > a.x) ? (t - a.x) / (b.x - a.x) : 1.0);
    }
  }
  for (int i = 0; i < 8; i++) {
    if (i >= uNGlows) break;
    vec4 g = uGlowA[i];
    vec2 d = vPos - g.xy;
    if (abs(d.x) > g.z || abs(d.y) > g.z) continue;
    float q = length(d) / (g.z * 1.41421356);
    if (q >= 1.0) continue;
    float a = q <= 0.6 ? g.w * (1.0 - 0.72 * q / 0.6) : g.w * 0.28 * (1.0 - (q - 0.6) / 0.4);
    c = mix(c, uGlowB[i].rgb, a);
  }
  if (uHasGrain == 1) {
    vec4 g = texture(uGrain, vPos / uGrainTile);          // premultiplied tile, REPEAT
    c = c * (1.0 - g.a * uGrainOp) + g.rgb * uGrainOp;
  }
  o = vec4(c, 1.0);
}
`,t=`#version 300 es
precision highp float;
precision highp sampler3D;
in vec2 vPos;
uniform sampler2D uTex;
uniform vec4 uContent;
uniform vec4 uWin;
uniform float uRadius;
uniform int uHasWin;
uniform float uPx;
uniform sampler3D uLut;
uniform int uLutN;
uniform sampler3D uRef;
uniform int uRefN;
uniform float uSplit;
out vec4 o;
${e}
float sdRound(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
  vec2 uv = (vPos - uContent.xy) / uContent.zw;
  float cov = 1.0;
  if (uHasWin == 1) {
    vec2 h = uWin.zw * 0.5;
    float d = sdRound(vPos - (uWin.xy + h), h, min(uRadius, min(h.x, h.y)));
    cov = clamp(0.5 - d / uPx, 0.0, 1.0);
  }
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) cov = 0.0;
  if (cov <= 0.0) discard;
  vec3 c = texture(uTex, clamp(uv, 0.0, 1.0)).rgb;
  bool left = uSplit >= 0.0 && vPos.x < uSplit;
  if (left) { if (uRefN > 1) c = tetra(uRef, uRefN, c); }
  else if (uLutN > 1) c = tetra(uLut, uLutN, c);
  o = vec4(c * cov, cov);
}
`,r=`#version 300 es
precision highp float;
in vec2 vUV;
uniform sampler2D uTex;
uniform int uMode;
uniform int uPremul;
uniform float uHalfTexel;
uniform float uBright;
uniform float uGray;
uniform float uOpacity;
uniform vec2 uQuadPx;
uniform int uMaskOnly;
uniform vec4 uUvRect;
out vec4 o;
void main() {
  vec2 e = min(vUV, 1.0 - vUV) * uQuadPx;
  float cov = clamp(min(e.x, e.y) + 0.5, 0.0, 1.0);
  if (cov <= 0.0) discard;
  // the quad shows the part uUvRect of the picture (a crop); the whole picture is (0, 0)–(1, 1)
  vec2 uv = mix(uUvRect.xy, uUvRect.zw, clamp(vUV, 0.0, 1.0));
  vec3 rgb; float a;
  if (uMode == 2) {
    float vt = clamp(uv.y * 0.5, uHalfTexel, 0.5 - uHalfTexel);
    float vb = clamp(0.5 + uv.y * 0.5, 0.5 + uHalfTexel, 1.0 - uHalfTexel);
    vec3 pm = texture(uTex, vec2(uv.x, vt)).rgb;
    a = clamp(texture(uTex, vec2(uv.x, vb)).r, 0.0, 1.0);
    rgb = a > 0.0 ? min(pm / a, vec3(1.0)) : vec3(0.0);
  } else {
    vec4 t = texture(uTex, uv);
    a = uMode == 0 ? 1.0 : t.a;
    rgb = (uPremul == 1 && uMode != 0) ? (t.a > 0.0 ? t.rgb / t.a : vec3(0.0)) : t.rgb;
  }
  a *= uOpacity * cov;
  if (uMaskOnly == 1) { o = vec4(a); return; }
  if (uBright != 1.0 || uGray > 0.0) {
    rgb = clamp(rgb * uBright, 0.0, 1.0);
    float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    rgb = mix(rgb, vec3(y), clamp(uGray, 0.0, 1.0));
  }
  o = vec4(rgb * a, a);
}
`,a=`#version 300 es
precision highp float;
in vec2 vPos;
uniform vec4 uWin;
uniform float uRadius;
uniform float uPx;
out vec4 o;
float sdRound(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
  vec2 h = uWin.zw * 0.5;
  float d = sdRound(vPos - (uWin.xy + h), h, min(uRadius, min(h.x, h.y)));
  o = vec4(clamp(0.5 - d / uPx, 0.0, 1.0));
}
`,v=`#version 300 es
precision highp float;
uniform sampler2D uSrc;
uniform vec2 uDir;
uniform float uSigma;
uniform int uRadius;
uniform vec2 uSize;
out vec4 o;
void main() {
  vec2 tc = gl_FragCoord.xy / uSize;
  if (uSigma < 0.3) { o = texture(uSrc, tc); return; }
  float k = -0.5 / (uSigma * uSigma);
  vec4 acc = texture(uSrc, tc);
  float wsum = 1.0;
  for (int i = 1; i <= 160; i++) {
    if (i > uRadius) break;
    float w = exp(float(i * i) * k);
    acc += w * (texture(uSrc, tc + uDir * float(i)) + texture(uSrc, tc - uDir * float(i)));
    wsum += 2.0 * w;
  }
  o = acc / wsum;
}
`,n=`#version 300 es
precision highp float;
in vec2 vPos;
uniform sampler2D uMask;
uniform vec2 uFrame;
uniform vec2 uOff;
uniform vec3 uColor;
uniform float uAlpha;
out vec4 o;
void main() {
  vec2 p = vPos - uOff;
  float m = texture(uMask, vec2(p.x / uFrame.x, 1.0 - p.y / uFrame.y)).r;
  float a = clamp(m * uAlpha, 0.0, 1.0);
  o = vec4(uColor * a, a);
}
`,l=`#version 300 es
precision highp float;
in vec2 vPos;
uniform sampler2D uSrc;
uniform vec2 uFrame;
uniform float uBright;
uniform float uAlpha;
out vec4 o;
void main() {
  vec4 c = texture(uSrc, vec2(vPos.x / uFrame.x, 1.0 - vPos.y / uFrame.y));
  o = vec4(c.rgb * uBright, c.a) * uAlpha;
}
`,f=`#version 300 es
precision highp float;
in vec2 vUV;
uniform sampler2D uSrc;
uniform vec4 uRect;
uniform vec2 uFrame;
out vec4 o;
void main() {
  vec2 p = uRect.xy + vUV * uRect.zw;
  o = texture(uSrc, vec2(p.x / uFrame.x, 1.0 - p.y / uFrame.y));
}
`,m=`#version 300 es
precision highp float;
in vec2 vUV;
uniform sampler2D uSrc;
uniform int uDisplay;
uniform int uQuant;
out vec4 o;
${i}
void main() {
  vec4 c = texture(uSrc, vec2(vUV.x, 1.0 - vUV.y));
  vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  rgb = clamp(rgb, 0.0, 1.0);
  if (uDisplay == 1) rgb = apple709(rgb);
  if (uQuant == 1) rgb = floor(rgb * 255.0 + 0.5) / 255.0;
  o = vec4(rgb, 1.0);
}
`,s=`#version 300 es
precision highp float;
precision highp usampler2D;
uniform usampler2D uSrc;
out vec4 o;
void main() {
  o = vec4(texelFetch(uSrc, ivec2(gl_FragCoord.xy), 0)) / 65535.0;
}
`,x=`#version 300 es
precision highp float;
precision highp usampler2D;
uniform usampler2D uSrc;
out vec4 o;
void main() {
  ivec2 p = ivec2(gl_FragCoord.xy);
  int x = 3 * p.x;
  o = vec4(float(texelFetch(uSrc, ivec2(x, p.y), 0).r), float(texelFetch(uSrc, ivec2(x + 1, p.y), 0).r),
           float(texelFetch(uSrc, ivec2(x + 2, p.y), 0).r), 65535.0) / 65535.0;
}
`,p=`#version 300 es
precision highp float;
uniform sampler2D uTex;
uniform ivec2 uBase;
uniform ivec2 uMax;
out vec4 o;
void main() {
  ivec2 p = clamp(uBase + ivec2(gl_FragCoord.xy), ivec2(0), uMax);
  o = texelFetch(uTex, p, 0);
}
`;export{c as FS_BG,v as FS_BLUR,l as FS_EDGES,p as FS_FETCH,m as FS_FINAL,r as FS_OVERLAY,f as FS_REGION,a as FS_RRECT,n as FS_TINT,s as FS_UNPACK16,x as FS_UNPACK48,t as FS_VIDEO,i as GLSL_APPLE709,e as GLSL_TETRA,o as VS,u as VS_FULL};
