const t=`
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
`,u=`
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
`,i=`#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
`,r=`#version 300 es
precision highp float;
in vec2 vPos;
uniform vec2 uFrame;
uniform vec4 uStops[8];
uniform int uNStops;
uniform vec4 uGlowA[8];
uniform vec4 uGlowB[8];
uniform int uNGlows;
uniform sampler2D uGrain;
uniform sampler2D uPhoto;     // «أخرى»: a picture he attached (premultiplied, mipmapped)
uniform int uHasPhoto;
uniform vec4 uPhotoFit;       // cover-fit: scale x, scale y, and the mip level of the blur (0 = sharp), the dim factor
uniform int uHasGrain;
uniform float uGrainOp;
uniform float uGrainTile;
uniform vec2 uNoise;          // fine grain: amount, cell size in frame px (a hash of the cell: still, and the same in the preview and the export)
uniform float uVig;           // soft vignette: how much the corners darken
uniform vec4 uGrid;           // fine grid: step, line width (frame px), a heavier line every this many, alpha of the fine line
uniform vec4 uGridB;          // the grid's colour and the alpha of the heavier line
out vec4 o;
uint bgHash(uvec2 v) {
  uint h = v.x * 1597334677u ^ v.y * 3812015801u;
  h ^= h >> 16; h *= 2246822519u; h ^= h >> 13; h *= 3266489917u; h ^= h >> 16;
  return h;
}
float gridLine(float v, float step, float w) {
  float g = v / step;
  return 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.5, abs(g - floor(g + 0.5)) * step);
}
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
    if (uGlowB[i].a > 0.5) {                               // soft: a plain circle of radius g.z, no square edge
      float sq = length(d) / g.z;
      if (sq >= 1.0) continue;
      float st = 1.0 - sq;
      c = mix(c, uGlowB[i].rgb, g.w * st * st * (3.0 - 2.0 * st));
      continue;
    }
    if (abs(d.x) > g.z || abs(d.y) > g.z) continue;
    float q = length(d) / (g.z * 1.41421356);
    if (q >= 1.0) continue;
    float a = q <= 0.6 ? g.w * (1.0 - 0.72 * q / 0.6) : g.w * 0.28 * (1.0 - (q - 0.6) / 0.4);
    c = mix(c, uGlowB[i].rgb, a);
  }
  if (uHasPhoto == 1) {                                    // the picture, cover-fitted to the frame, over the colour under it
    vec2 uv = (vPos / uFrame - 0.5) * uPhotoFit.xy + 0.5;
    vec4 s = textureLod(uPhoto, uv, uPhotoFit.z);
    if (uPhotoFit.z > 0.0) {                               // blurred: four more taps half a texel of that level away, so the mip's blocks melt
      vec2 e = 0.5 * exp2(uPhotoFit.z) / vec2(textureSize(uPhoto, 0));
      s = 0.2 * s + 0.2 * (textureLod(uPhoto, uv + e, uPhotoFit.z) + textureLod(uPhoto, uv - e, uPhotoFit.z)
        + textureLod(uPhoto, uv + vec2(e.x, -e.y), uPhotoFit.z) + textureLod(uPhoto, uv + vec2(-e.x, e.y), uPhotoFit.z));
    }
    c = (s.rgb + c * (1.0 - s.a)) * uPhotoFit.w;
  }
  if (uVig > 0.0) {
    float q = length((vPos / uFrame - 0.5) * 2.0) / 1.41421356;
    c *= 1.0 - uVig * smoothstep(0.3, 1.0, q);
  }
  if (uGrid.x > 0.0) {
    vec2 gp = vPos - uFrame * 0.5;
    float minor = max(gridLine(gp.x, uGrid.x, uGrid.y), gridLine(gp.y, uGrid.x, uGrid.y));
    float major = max(gridLine(gp.x, uGrid.x * uGrid.z, uGrid.y * 1.6), gridLine(gp.y, uGrid.x * uGrid.z, uGrid.y * 1.6));
    c = mix(c, uGridB.rgb, max(minor * uGrid.w, major * uGridB.w));
  }
  if (uNoise.x > 0.0) {
    uvec2 cell = uvec2(floor(vPos / uNoise.y));
    c += (float(bgHash(cell) >> 8) / 8388608.0 - 1.0) * uNoise.x;
  }
  if (uHasGrain == 1) {
    vec4 g = texture(uGrain, vPos / uGrainTile);          // premultiplied tile, REPEAT
    c = c * (1.0 - g.a * uGrainOp) + g.rgb * uGrainOp;
  }
  o = vec4(c, 1.0);
}
`,e=`
uniform int uFlick;
uniform float uFlickDark;
uniform float uFlickGain;
uniform vec4 uFlash;
uniform vec4 uLeak;
uniform vec4 uLeakCol;
uniform vec4 uSpot;
uniform float uSpotAmt;
vec3 lightFx(vec3 c, vec2 pos) {
  if (uFlick == 1) c *= uFlickDark;
  else if (uFlick == 2) {
    vec3 b = min(vec3(1.0), c * 0.4 + 0.7);
    c = uFlickGain == 1.0 ? b : clamp(c + (b - c) * uFlickGain, 0.0, 1.0);
  }
  if (uFlash.a > 0.0) c = mix(c, uFlash.rgb, clamp(uFlash.a, 0.0, 1.0));
  if (uLeakCol.a > 0.0) {
    vec2 d = (pos - uLeak.xy) / uLeak.zw;
    float g = exp(-dot(d, d)) * uLeakCol.a;
    c = 1.0 - (1.0 - clamp(c, 0.0, 1.0)) * (1.0 - clamp(g * uLeakCol.rgb, 0.0, 1.0));
  }
  if (uSpotAmt > 0.0) c *= 1.0 - uSpotAmt * smoothstep(uSpot.z, uSpot.z + uSpot.w, length(pos - uSpot.xy));
  return c;
}
`,c=`#version 300 es
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
uniform vec4 uFace;
uniform float uFaceAmt;
uniform float uRot;
uniform vec2 uRotC;
uniform int uBlurN;
uniform vec4 uContentA;
uniform float uRotA;
uniform vec2 uRotCA;
uniform vec4 uContent2;
uniform float uRot2;
uniform vec2 uRotC2;
uniform int uMirror;
uniform float uRgb;
uniform sampler2D uMatte;
uniform int uHasMatte;
uniform vec2 uMatteTexel;
out vec4 o;
${e}
${t}
float matteAt(vec2 q) {
  vec2 d = uMatteTexel;
  float m = 4.0 * texture(uMatte, q).r
    + 2.0 * (texture(uMatte, q + vec2(d.x, 0.0)).r + texture(uMatte, q - vec2(d.x, 0.0)).r
           + texture(uMatte, q + vec2(0.0, d.y)).r + texture(uMatte, q - vec2(0.0, d.y)).r)
    + texture(uMatte, q + d).r + texture(uMatte, q - d).r
    + texture(uMatte, q + vec2(d.x, -d.y)).r + texture(uMatte, q + vec2(-d.x, d.y)).r;
  return clamp((m / 16.0 - 0.08) / 0.84, 0.0, 1.0);
}
float sdRound(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec2 srcUV(vec2 pos, vec4 content, float ang, vec2 rc) {
  vec2 q = pos;
  if (ang != 0.0) {
    vec2 d = pos - rc;
    float cs = cos(ang), sn = sin(ang);
    q = rc + vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
  }
  return (q - content.xy) / content.zw;
}
vec2 fold(vec2 uv) {
  if (uMirror == 1) { vec2 m = mod(uv, 2.0); return 1.0 - abs(1.0 - m); }
  return clamp(uv, 0.0, 1.0);
}
vec3 graded(vec2 uv, bool left) {
  vec3 c = texture(uTex, uv).rgb;
  if (left) { if (uRefN > 1) c = tetra(uRef, uRefN, c); }
  else {
    if (uLutN > 1) c = tetra(uLut, uLutN, c);
    // «إضاءة الوجه»: a soft oval of light on his face (centre a little below the box's middle), up to +40 % at 100
    if (uFaceAmt > 0.0) {
      vec2 d = (uv - uFace.xy) / max(uFace.zw, vec2(1e-3));
      c *= 1.0 + 0.4 * uFaceAmt * (1.0 - smoothstep(0.45, 1.0, length(d)));
    }
  }
  return c;
}
vec3 colorAt(vec2 pos, bool left) {
  if (uBlurN <= 1) return graded(fold(srcUV(pos, uContent, uRot, uRotC)), left);
  vec3 acc = vec3(0.0);
  for (int k = 0; k < 24; k++) {
    if (k >= uBlurN) break;
    float w = float(k) / float(uBlurN - 1);
    acc += graded(fold(srcUV(pos, mix(uContentA, uContent2, w), mix(uRotA, uRot2, w), mix(uRotCA, uRotC2, w))), left);
  }
  return acc / float(uBlurN);
}
// the person's matte where this pixel's picture is read (the same samples as colorAt under motion blur)
float matteCov(vec2 pos) {
  if (uBlurN <= 1) return matteAt(fold(srcUV(pos, uContent, uRot, uRotC)));
  float acc = 0.0;
  for (int k = 0; k < 24; k++) {
    if (k >= uBlurN) break;
    float w = float(k) / float(uBlurN - 1);
    acc += matteAt(fold(srcUV(pos, mix(uContentA, uContent2, w), mix(uRotA, uRot2, w), mix(uRotCA, uRotC2, w))));
  }
  return acc / float(uBlurN);
}
void main() {
  vec2 uv = srcUV(vPos, uContent, uRot, uRotC);
  float cov = 1.0;
  if (uHasWin == 1) {
    vec2 h = uWin.zw * 0.5;
    float d = sdRound(vPos - (uWin.xy + h), h, min(uRadius, min(h.x, h.y)));
    cov = clamp(0.5 - d / uPx, 0.0, 1.0);
  }
  if (uMirror == 0 && (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)) cov = 0.0;
  if (uHasMatte == 1 && cov > 0.0) cov *= matteCov(vPos);
  if (cov <= 0.0) discard;
  bool left = uSplit >= 0.0 && vPos.x < uSplit;
  vec3 c = colorAt(vPos, left);
  if (uRgb > 0.0) {
    c.r = colorAt(vPos - vec2(uRgb, 0.0), left).r;
    c.b = colorAt(vPos + vec2(uRgb, 0.0), left).b;
  }
  c = lightFx(c, vPos);
  o = vec4(c * cov, cov);
}
`,a=`#version 300 es
precision highp float;
in vec2 vPos;
uniform sampler2D uSrc;
uniform vec2 uFrame;
uniform vec4 uContent;
uniform vec4 uWin;
uniform float uRadius;
uniform int uHasWin;
uniform float uPx;
uniform float uRot;
uniform vec2 uRotC;
uniform int uMirror;
out vec4 o;
${e}
float sdRound(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
  vec2 q = vPos;
  if (uRot != 0.0) {
    vec2 d = vPos - uRotC;
    float cs = cos(uRot), sn = sin(uRot);
    q = uRotC + vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
  }
  vec2 uv = (q - uContent.xy) / uContent.zw;
  float cov = 1.0;
  if (uHasWin == 1) {
    vec2 h = uWin.zw * 0.5;
    float d = sdRound(vPos - (uWin.xy + h), h, min(uRadius, min(h.x, h.y)));
    cov = clamp(0.5 - d / uPx, 0.0, 1.0);
  }
  if (uMirror == 0 && (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)) cov = 0.0;
  if (cov <= 0.0) discard;
  vec4 s = texture(uSrc, vec2(vPos.x / uFrame.x, 1.0 - vPos.y / uFrame.y));
  vec3 c = s.a > 0.0 ? s.rgb / s.a : vec3(0.0);
  c = lightFx(c, vPos);
  float a = s.a * cov;
  o = vec4(c * a, a);
}
`,n=`#version 300 es
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
`,v=`#version 300 es
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
`,f=`#version 300 es
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
`,l=`#version 300 es
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
`,m=`#version 300 es
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
`,s=`#version 300 es
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
`,x=`#version 300 es
precision highp float;
in vec2 vUV;
uniform sampler2D uSrc;
uniform int uDisplay;
uniform int uQuant;
out vec4 o;
${u}
void main() {
  vec4 c = texture(uSrc, vec2(vUV.x, 1.0 - vUV.y));
  vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  rgb = clamp(rgb, 0.0, 1.0);
  if (uDisplay == 1) rgb = apple709(rgb);
  if (uQuant == 1) rgb = floor(rgb * 255.0 + 0.5) / 255.0;
  o = vec4(rgb, 1.0);
}
`,p=`#version 300 es
precision highp float;
precision highp usampler2D;
uniform usampler2D uSrc;
out vec4 o;
void main() {
  o = vec4(texelFetch(uSrc, ivec2(gl_FragCoord.xy), 0)) / 65535.0;
}
`,h=`#version 300 es
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
`,d=`#version 300 es
precision highp float;
uniform sampler2D uTex;
uniform ivec2 uBase;
uniform ivec2 uMax;
out vec4 o;
void main() {
  ivec2 p = clamp(uBase + ivec2(gl_FragCoord.xy), ivec2(0), uMax);
  o = texelFetch(uTex, p, 0);
}
`,g=`#version 300 es
precision highp float;
in vec2 vPos;
uniform sampler2D uA;
uniform sampler2D uB;
uniform vec2 uFrame;
uniform int uKind;
uniform float uU;
uniform vec3 uColor;
uniform vec2 uOffA;
uniform vec2 uOffB;
uniform int uAxis;
uniform float uEdge;
uniform float uFrom;
out vec4 o;
vec4 at(sampler2D t, vec2 p) { return texture(t, vec2(p.x / uFrame.x, 1.0 - p.y / uFrame.y)); }
bool inside(vec2 p) { return p.x >= 0.0 && p.y >= 0.0 && p.x < uFrame.x && p.y < uFrame.y; }
void main() {
  vec2 p = vPos;
  if (uKind == 0) { o = mix(at(uA, p), at(uB, p), uU); return; }
  if (uKind == 1) {
    vec4 c = vec4(uColor, 1.0);
    o = uU < 0.5 ? mix(at(uA, p), c, 2.0 * uU) : mix(c, at(uB, p), 2.0 * uU - 1.0);
    return;
  }
  if (uKind == 2 || uKind == 3) {
    vec2 q = p - uOffB;
    if (inside(q)) { o = at(uB, q); return; }
    o = at(uA, uKind == 3 ? p - uOffA : p);
    return;
  }
  float c = uAxis == 0 ? p.x : p.y;
  bool b = uFrom < 0.0 ? c < uEdge : c >= uEdge;
  o = b ? at(uB, p) : at(uA, p);
}
`,b=`#version 300 es
precision highp float;
precision highp int;
precision highp isampler2D;
uniform sampler2D uSrc;
uniform isampler2D uFilt;
uniform int uW;
uniform int uH;
uniform int uTW;
uniform int uSize;
uniform ivec3 uY;
uniform ivec3 uU;
uniform ivec3 uV;
out vec4 o;
ivec3 px(int x, int y) { return ivec3(round(texelFetch(uSrc, ivec2(x, y), 0).rgb * 255.0)); }
int luma(int b) {
  ivec3 c = px(b % uW, b / uW);
  int y14 = (c.r * uY.x + c.g * uY.y + c.b * uY.z + (1 << 19) + (1 << 8)) >> 9;
  return clamp((min(y14 * 2, 32767) + 64) >> 7, 0, 255);
}
int chroma(int k, ivec3 m) {
  int cw = uW >> 1;
  int cx = k % cw, cy = k / cw;
  int p0 = texelFetch(uFilt, ivec2(0, cy), 0).r;
  int s = 64 << 12;
  for (int j = 0; j < 64; j++) {
    if (j >= uSize) break;
    int f = texelFetch(uFilt, ivec2(1 + j, cy), 0).r;
    if (f == 0) continue;
    ivec3 a = px(2 * cx, p0 + j) + px(2 * cx + 1, p0 + j);
    int u = (a.r * m.x + a.g * m.y + a.b * m.z + (1 << 23) + (1 << 9)) >> 10;
    s += min((u & 0xffff) * 2, 32767) * f;
  }
  return clamp(s >> 19, 0, 255);
}
int byteAt(int b) {
  int n = uW * uH;
  if (b < n) return luma(b);
  b -= n;
  int m = (uW >> 1) * (uH >> 1);
  if (b < m) return chroma(b, uU);
  b -= m;
  if (b < m) return chroma(b, uV);
  return 0;
}
void main() {
  int t = (int(gl_FragCoord.y) * uTW + int(gl_FragCoord.x)) * 4;
  o = vec4(float(byteAt(t)), float(byteAt(t + 1)), float(byteAt(t + 2)), float(byteAt(t + 3))) / 255.0;
}
`;export{r as FS_BG,f as FS_BLUR,m as FS_EDGES,d as FS_FETCH,x as FS_FINAL,b as FS_I420,a as FS_LIGHT,n as FS_OVERLAY,s as FS_REGION,v as FS_RRECT,l as FS_TINT,g as FS_TRANS,p as FS_UNPACK16,h as FS_UNPACK48,c as FS_VIDEO,u as GLSL_APPLE709,e as GLSL_LIGHT,t as GLSL_TETRA,o as VS,i as VS_FULL};
