#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"

#ifdef COMPILEPS
uniform float cBeamAttenuation;
uniform float cBeamAnglePower;
uniform float cBeamIntensity;
uniform float cBeamFadeScale;
#endif

#if defined(PLANESPOT)
    varying vec2 vTexCoord;
#endif

varying vec3 vSpotlightPosition;
varying vec3 vNormal;
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
#ifndef PLANESPOT
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix); 
    gl_Position = GetClipPos(worldPos);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    // Get normal of  geom light in view space
    vNormal = GetViewNormal(cView);
    vViewPos = normalize(GetViewPos(cView));
    vScreenPos = GetScreenPos(gl_Position);
    
    vSpotlightPosition = (vec4(0,0,0,1.0) * modelMatrix).xyz;
    vFarRay = GetFarRay(gl_Position);
    
    vView = transpose(cViewInv);
    //vViewPos =  worldPos * mat3(cViewInv); 
    //vNormal = GetWorldNormal(modelMatrix);
    //vNormal = normalize(mat3(cViewInv) * vNormal);
    
    
    vSpotForwardWorld = normalize((vec4(0,-1,0,1) * modelMatrix).xyz); 
    vSpotForwardView = vSpotForwardWorld * mat3(cViewInv);
#else
    mat4 modelMatrix = iModelMatrix;    
    mat4 MV = modelMatrix * cView ; 
    
    MV[0][0] = 1.0;
    MV[0][1] = 0.0;
    MV[0][2] = 0.0;
    
    MV[1][0] = 0.0;
    MV[1][1] = 1.0;
    MV[1][2] = 0.0;
    
    MV[2][0] = 0.0;
    MV[2][1] = 0.0;
    MV[2][2] = 1.0;

    //gl_Position = cViewProj * cView * iPos + vec4(iPos.x, iPos.y, 0, 0);
    
    vec3 worldPos = GetWorldPos(modelMatrix);  
    vec4 p =  iPos * MV;
    gl_Position = p * cProj;
    vTexCoord = iTexCoord;
    
    vec3 nodeForward = vec3(0,0,1) * transpose(mat3(modelMatrix)); 
    vSpotForwardWorld = normalize(vec4(nodeForward,1) * MV).xyz; 
    //vSpotForwardView =  vSpotForwardWorld * mat3(cViewInv);
    vec3 viewDir = normalize(vec3(0,0,1) * mat3(cView));
    
    vAngle = (dot(vSpotForwardWorld,  viewDir ));
    
#endif
}

#endif

void PS()
{
#ifndef PLANESPOT
    float intensity = cBeamIntensity;
    float attenuation = cBeamAttenuation;
    float anglePower = cBeamAnglePower;
    
    //intensity	= distance(vWorldPos.xyz, vSpotlightPosition) / attenuation;
    intensity	= distance(vWorldPos.xyz, vSpotlightPosition) / attenuation;
    
    //intensity	=  distance(vWorldPos.xyz, vSpotlightPosition);
    intensity	= 1.0 - clamp(intensity, 0.0, 1.0);
    
    
    vec3 vsNormal	= vNormal;
    
    //vec3 dir = vec3(0,0,1) * vCamRot;
    //vec3 dir = (vViewPos);
    
    //vec3 dir = normalize(vFarRay * mat3(vView));
    //vec3 dir = normalize(vec4(vec3(0,0,1),0) * vView).xyz;    
    //vec3 dir = normalize(cCameraPosPS - vWorldPos.xyz);
    //dir = normalize(dir * mat3(vView)); 
    vec3 dir = vViewPos;
    
    float angleIntensity	= pow( abs(dot(vsNormal,dir)), anglePower );
    //float angleIntensity2 = pow( abs(dot(vsNormal,vSpotForwardView)), anglePower );
    
    //float forwardIntensity = abs(dot(vSpotForwardView, vec3(1,0,0)));
    float forwardIntensity = pow(abs(dot(vSpotForwardView, vec3(0,0,1))), anglePower);
    
    intensity	= intensity * angleIntensity;
        
    vec4 diffColor = cMatDiffColor;
        
    //SOFT
    float BeamDepth = vWorldPos.w;
    #ifdef HWDEPTH
        float depth = ReconstructDepth(texture2DProj(sDepthBuffer, vScreenPos).r);
    #else
        float depth = DecodeDepth(texture2DProj(sDepthBuffer, vScreenPos).rgb);
    #endif

    float diffZ = (depth - BeamDepth) * (cFarClipPS - cNearClipPS);
    float fade = clamp(1.0 - diffZ * cBeamFadeScale, 0.0, 1.0);
    
    //float diffZ = max(BeamDepth - depth, 0.0) * (cFarClipPS - cNearClipPS);
    //float fade = clamp(diffZ * cBeamFadeScale, 0.0, 1.0);
    
    #define ADDITIVE
    #ifndef ADDITIVE
        diffColor.a = max(diffColor.a - fade, 0.0);
    #else
        diffColor.rgb = max(diffColor.rgb - fade, vec3(0.0, 0.0, 0.0));
    #endif
    
    gl_FragColor = vec4(intensity * diffColor);
#else
    vec4 diffInput = texture2D(sDiffMap, vTexCoord);
    gl_FragColor = vec4(vAngle * diffInput * cMatDiffColor);
#endif

}
