#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"

#ifdef COMPILEPS
uniform float cBeamAttenuation;
uniform float cBeamAnglePower;
uniform float cBeamFadeScale;
uniform float cBeamForwardPower;
#endif

#if defined(PLANESPOT)
    varying vec2 vTexCoord;
#endif
varying vec2 vTexCoord;
varying vec3 vSpotlightPosition;
varying vec3 vNormalVS;
varying vec3 vNormalWS;
varying vec4 vWorldPos;
varying vec3 vFarRay;
varying mat4 vView;
varying vec3 vViewPos;
varying vec3 vSpotForwardWorld;
varying vec3 vSpotForwardView;
varying float vAngle;
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

#line 30
void VS()
{
    mat4 modelMatrix = iModelMatrix;
    //vec3 worldPos = (iPos * iModelMatrix).xyz;
    vec3 worldPos = GetWorldPos(modelMatrix); 
    gl_Position = GetClipPos(worldPos);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    // Get normal of  geom light in view space
    vNormalVS = GetViewNormal(cView);
    vNormalWS = GetWorldNormal(modelMatrix);
    vViewPos = GetViewPos(cView);
    vScreenPos = GetScreenPos(gl_Position);
    
    vSpotlightPosition = (vec4(0,0,0,1.0) * modelMatrix).xyz;
    vFarRay = GetFarRay(gl_Position);
    
    vTexCoord = iTexCoord;
    vSpotForwardWorld = (vec4(0,-1,0,0) * iModelMatrix).xyz;
    vSpotForwardView = normalize(vSpotForwardWorld * mat3(cView));
}

#endif

void PS()
{
    float attenuation = cBeamAttenuation;
    float anglePower = cBeamAnglePower;
    
    float IntensityOverLength	= distance(vWorldPos.xyz, vSpotlightPosition) / attenuation;
    IntensityOverLength	= 1.0 - clamp(IntensityOverLength, 0.0, 1.0);
        
    vec3 EyeDirWS = normalize(cCameraPosPS - vWorldPos.xyz);
    
    float angleIntensity = clamp(abs(dot(vNormalWS, EyeDirWS)), 0, 1);
    angleIntensity	= pow( angleIntensity, anglePower );
    
    float angleIntensityForward = clamp(abs(dot(vSpotForwardView, vec3(0,0,1))), 0, 1);
        
    float FinalIntensity	= IntensityOverLength * (angleIntensity + (angleIntensityForward * cBeamForwardPower));
            
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
    
    diffColor.rgb = FinalIntensity * max(diffColor.rgb - fade, vec3(0.0, 0.0, 0.0));
    
    gl_FragColor = vec4(diffColor);

}
