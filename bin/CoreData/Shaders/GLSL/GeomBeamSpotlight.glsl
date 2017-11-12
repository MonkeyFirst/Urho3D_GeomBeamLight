#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"

#ifdef COMPILEVS
uniform float cBeamAttenuation;
uniform float cBeamAnglePower;
uniform float cBeamForwardPower;
#endif

#ifdef COMPILEPS
uniform float cBeamFadeScale;
uniform float cBeamIntensity;
#endif

varying vec4 beam; 
#define BEAM_FOV beam.x
#define BEAM_INTENSITY beam.y
#define BEAM_INTENSITY_ANGLE beam.z
#define BEAM_INTENSITY_FORWARD beam.w

varying vec2 vTexCoord;
varying vec4 vWorldPos;
varying vec4 vScreenPos;
    
#ifdef COMPILEVS

vec3 GetViewFarRay(vec4 clipPos)
{
    return vec3(cFrustumSize.x * clipPos.x,
                cFrustumSize.y * clipPos.y,
                cFrustumSize.z);
}

mat3 GetModelNormalMatrix(mat4 modelMatrix)
{
    return mat3(modelMatrix[0].xyz, modelMatrix[1].xyz, modelMatrix[2].xyz);
}

vec3 GetViewPos(mat4 viewMatrix)
{
    return (iPos * iModelMatrix * viewMatrix).xyz;
}

vec3 GetViewNormal(mat4 viewMatrix)
{
    // mesh normal to object normal space
    vec3 obNormal = iNormal * mat3(iModelMatrix);
    // object normal to view space
    return normalize(obNormal * mat3(viewMatrix));
}

#line 60
void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix); 
    gl_Position = GetClipPos(worldPos);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    vTexCoord = iTexCoord;
    vScreenPos = GetScreenPos(gl_Position);
    
    //vec3 vNormalVS = GetViewNormal(cView);
    vec3 vNormalWS = GetWorldNormal(modelMatrix);
    
    vec3 vSpotlightPosition = (vec4(0,0,0,1.0) * modelMatrix).xyz;
    vec3 vSpotForwardWorld = normalize((vec4(0,-1,0,0) * iModelMatrix).xyz);
    vec3 vSpotForwardView = normalize(vSpotForwardWorld * mat3(cView));
    
    vec3 eyeDir = normalize(cCameraPos - vWorldPos.xyz);
    
    BEAM_FOV = abs(dot(vSpotForwardWorld, normalize(cCameraPos - vSpotlightPosition)));
    BEAM_INTENSITY = distance(vWorldPos.xyz, vSpotlightPosition) / cBeamAttenuation;
    BEAM_INTENSITY = 1.0 - clamp(BEAM_INTENSITY, 0.0, 1.0);    
    BEAM_INTENSITY_ANGLE = pow(clamp(abs(dot(vNormalWS, eyeDir)), 0, 1), cBeamAnglePower);
    BEAM_INTENSITY_FORWARD = clamp(abs(dot(vSpotForwardView, vec3(0,0,1))), 0, 1);
    BEAM_INTENSITY_FORWARD *= cBeamForwardPower; 
}

#endif

void PS()
{    
    float FinalIntensity = mix(BEAM_INTENSITY * BEAM_INTENSITY_ANGLE, BEAM_INTENSITY * (BEAM_INTENSITY_ANGLE + BEAM_INTENSITY_FORWARD), BEAM_FOV);
    
    vec4 diffColor = cMatDiffColor;
        
    //SOFT BEGIN
    float BeamDepth = vWorldPos.w;
    #ifdef HWDEPTH
        float depth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r);
    #else
        float depth = DecodeDepth(texture2DProj(sDepthBuffer, vScreenPos).rgb);
    #endif

    float diffZ = (depth - BeamDepth) * (cFarClipPS - cNearClipPS);
    float fade = clamp(1.0 - diffZ * cBeamFadeScale, 0.0, 1.0);
    //SOFT END
    
    FinalIntensity *=cBeamIntensity;
    diffColor.rgb = FinalIntensity * max(diffColor.rgb - fade, vec3(0.0, 0.0, 0.0));
    
    gl_FragColor = vec4(diffColor);

}
