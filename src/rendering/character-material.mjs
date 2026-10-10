import { Mesh, MeshGeometry, Shader, Texture, UniformGroup } from 'pixi.js';

// Inputs are co-registered straight RGBA sources. Output is premultiplied once.
// The combined source retains the artist's occlusion and baked glow at neutral
// settings. The isolated sources provide the actual body-off / effect-off ends.
const vertex = `#version 300 es
precision highp float;
in vec2 aPosition;
in vec2 aUV;
uniform mat3 uProjectionMatrix;
uniform mat3 uWorldTransformMatrix;
uniform mat3 uTransformMatrix;
uniform vec4 uRegion;
out vec2 vUV;
void main() {
    vUV = uRegion.xy + aUV * uRegion.zw;
    gl_Position = vec4((uProjectionMatrix * uWorldTransformMatrix * uTransformMatrix
        * vec3(aPosition, 1.0)).xy, 0.0, 1.0);
}`;

const fragment = `#version 300 es
precision highp float;
precision highp sampler2D;
in vec2 vUV;
out vec4 outColor;
uniform sampler2D uCombined;
uniform sampler2D uBody;
uniform sampler2D uShadow;
uniform sampler2D uAccent;
uniform vec4 uColor;
uniform vec3 uStrength;
uniform vec2 uHue;
uniform vec3 uBodyTint;
uniform vec3 uAccentTint;
uniform float uHasAccent;
uniform float uReference;
vec4 pm(vec4 c) { return vec4(c.rgb * c.a, c.a); }
vec4 over(vec4 a, vec4 b) { return a + (1.0 - a.a) * b; }
float smallest(vec3 v) { return min(v.x, min(v.y, v.z)); }
float largest(vec3 v) { return max(v.x, max(v.y, v.z)); }
vec3 recolour(vec3 rgb, float turn, vec3 tint) {
    if (turn == 0.0) return rgb * tint;
    // HSV rotation preserves brightness and leaves neutral highlights neutral.
    float hi = largest(rgb), lo = smallest(rgb), d = hi - lo;
    if (d < 0.000001) return rgb * tint;
    float h;
    if (hi == rgb.r) h = (rgb.g - rgb.b) / d;
    else if (hi == rgb.g) h = 2.0 + (rgb.b - rgb.r) / d;
    else h = 4.0 + (rgb.r - rgb.g) / d;
    vec3 wave = clamp(abs(fract(h / 6.0 + turn + vec3(0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    return mix(vec3(lo), vec3(hi), wave) * tint;
}
vec4 visibleShadow(vec4 c, vec4 b, vec4 s, vec4 e) {
    vec3 srgb = s.rgb / max(s.a, 0.000001);
    float a = min(s.a * (1.0-b.a) * (1.0-e.a), c.a);
    // Outside both bodies/effects, use the observed shadow alpha: original
    // separate exports occasionally differ from the combined in alpha.
    if (b.a == 0.0 && e.a == 0.0 && s.a > 0.0
        && largest(abs(c.rgb / max(c.a, 0.000001) - srgb)) < 1.0/255.0 + 0.00001) a = c.a;
    a = min(a, smallest(vec3(srgb.r > 0.0 ? c.r/srgb.r : 1.0,
        srgb.g > 0.0 ? c.g/srgb.g : 1.0, srgb.b > 0.0 ? c.b/srgb.b : 1.0)));
    a = min(a, smallest(vec3(srgb.r < 1.0 ? max(c.a-c.r,0.0)/(1.0-srgb.r) : 1.0,
        srgb.g < 1.0 ? max(c.a-c.g,0.0)/(1.0-srgb.g) : 1.0,
        srgb.b < 1.0 ? max(c.a-c.b,0.0)/(1.0-srgb.b) : 1.0)));
    return vec4(srgb * a, a);
}
vec3 retainedBody(vec3 c, vec3 b, vec3 e) {
    float ee = dot(e,e), be = dot(b,e);
    float denominator = dot(b,b) - be*be/max(ee, 0.000000000001);
    // A nonnegative colour allocation, not recovered geometry or physical light.
    // Zero body channels do not constrain the retained-body coefficient.
    vec3 bounds = vec3(b.x > 0.0 ? c.x/b.x : 1.0,
        b.y > 0.0 ? c.y/b.y : 1.0, b.z > 0.0 ? c.z/b.z : 1.0);
    float limit = clamp(smallest(bounds), 0.0, 1.0);
    float coefficient = limit;
    if (ee > 0.0000000001 && denominator > 0.0000000001)
        coefficient = clamp((dot(c,b)-dot(c,e)*be/ee)/denominator, 0.0, limit);
    return b * coefficient;
}
void main() {
    vec4 c = pm(texture(uCombined, vUV));
    if (uReference > 0.5) { outColor = c * uColor; return; }
    vec4 b = pm(texture(uBody, vUV));
    vec4 s = pm(texture(uShadow, vUV));
    vec4 e = pm(texture(uAccent, vUV));
    vec4 h = visibleShadow(c,b,s,e), cf = c-h;
    float body = uStrength.x, shadow = uStrength.y, fx = uStrength.z;
    vec3 rb = uHasAccent > 0.5 ? retainedBody(cf.rgb,b.rgb,e.rgb) : cf.rgb;
    cf.rgb = min(vec3(cf.a), recolour(rb,uHue.x,uBodyTint)
        + recolour(max(cf.rgb-rb,vec3(0)),uHue.y,uAccentTint));
    b.rgb = recolour(b.rgb,uHue.x,uBodyTint);
    e.rgb = recolour(e.rgb,uHue.y,uAccentTint);
    s *= shadow;
    vec4 result;
    if (uHasAccent < 0.5) {
        // An empty original accent is not an effect to switch on and off.
        result = body*shadow*(cf+h) + body*(1.0-shadow)*b + (1.0-body)*s;
    } else {
        result = body*fx*(cf+shadow*h)
            + body*(1.0-fx)*over(b,s)
            + (1.0-body)*fx*over(e,s)
            + (1.0-body)*(1.0-fx)*s;
    }
    outColor = result * uColor;
}`;

/** Functional Pixi mesh, not an actor/animation/resource owner.
 * sources: {combined, body, shadow, accent}: aligned TextureSources loaded with
 * alphaMode='no-premultiply-alpha'. Use transparent accent for absent effects.
 * region: normalized [left, top, width, height] chosen by the existing clip.
 * size/pivot: caller supplies authored dimensions/contact; no creature resizing.
 * Caller owns textures. Destroy mesh geometry + shader, not shared sources.
 */
export function createCharacterMaterial({ sources, hasAccent, width, height, pivot = [0, 0], region = [0, 0, 1, 1] }) {
    const uniforms = new UniformGroup({
        uRegion: { value: new Float32Array(region), type: 'vec4<f32>' },
        uStrength: { value: new Float32Array([1,1,1]), type: 'vec3<f32>' },
        uHue: { value: new Float32Array([0,0]), type: 'vec2<f32>' },
        uBodyTint: { value: new Float32Array([1,1,1]), type: 'vec3<f32>' },
        uAccentTint: { value: new Float32Array([1,1,1]), type: 'vec3<f32>' },
        uHasAccent: { value: hasAccent ? 1 : 0, type: 'f32' },
        uReference: { value: 0, type: 'f32' },
    });
    const shader = Shader.from({ gl: { vertex, fragment }, resources: {
        uCombined: sources.combined, uBody: sources.body,
        uShadow: sources.shadow, uAccent: sources.accent,
        characterUniforms: uniforms,
    }});
    const geometry = new MeshGeometry({ positions: new Float32Array([0,0,width,0,width,height,0,height]), uvs: new Float32Array([0,0,1,0,1,1,0,1]) });
    // Texture.EMPTY deliberately selects normal premultiplied output blending;
    // the straight source samplers must not select normal-npm blending here.
    const mesh = new Mesh({ geometry, shader, texture: Texture.EMPTY });
    mesh.pivot.set(...pivot);
    return mesh;
}

/** Strengths 0..1, hue rotations in turns, tints RGB 0..1. No time/resource I/O. */
export function setCharacterControls(mesh, { body = 1, shadow = 1, accent = 1,
    bodyHue = 0, accentHue = 0, bodyTint = [1,1,1], accentTint = [1,1,1], reference = false } = {}) {
    const group = mesh.shader.resources.characterUniforms;
    group.uniforms.uStrength.set([body,shadow,accent]);
    group.uniforms.uHue.set([bodyHue,accentHue]);
    group.uniforms.uBodyTint.set(bodyTint);
    group.uniforms.uAccentTint.set(accentTint);
    group.uniforms.uReference = reference ? 1 : 0;
    group.update();
}

export function setCharacterRegion(mesh, region) {
    const group = mesh.shader.resources.characterUniforms;
    group.uniforms.uRegion.set(region);
    group.update();
}
