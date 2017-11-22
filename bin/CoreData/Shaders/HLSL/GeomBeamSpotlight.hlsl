#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"

#ifdef COMPILEVS
uniform float cBeamAttenuation;
uniform float cBeamAnglePower;
uniform float cBeamForwardPower;
#endif

#ifdef COMPILEPS
uniform float cBeamFadeScale;
uniform float cBeamIntensity;
#endif

void VS(float4 iPos : POSITION,
        float3 iNormal : NORMAL,    
    #ifdef INSTANCED
        float4x3 iModelInstance : TEXCOORD4,
    #endif
    #if defined(D3D11) && defined(CLIPPLANE)
        out float oClip : SV_CLIPDISTANCE0,
    #endif
    out float4 oWorldPos : TEXCOORD2,
    out float2 oScreenPos : TEXCOORD5,
    out float4 oBeamParam : TEXCOORD6,
    out float4 oPos : OUTPOSITION)
{
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    oPos = GetClipPos(worldPos);
    oScreenPos = GetScreenPosPreDiv(oPos);
    oWorldPos = float4(worldPos, GetDepth(oPos));
    
    float3 NormalWS = GetWorldNormal(modelMatrix);
    float3 SpotlightPosition = mul(float4(0.0, 0.0, 0.0, 1.0), modelMatrix).xyz;
    
    float3 SpotForwardWorld = normalize(mul(float4(0,1,0,1), modelMatrix).xyz);
    float3 SpotForwardView = normalize(mul(SpotForwardWorld, (float3x3)(cView)));
    
    float3 eyeDir = normalize(cCameraPos - worldPos.xyz);
    
    oBeamParam.x = abs(dot(SpotForwardWorld, normalize(cCameraPos - SpotlightPosition)));
    
    float fIntensity = distance(worldPos.xyz, SpotlightPosition) / cBeamAttenuation;
    oBeamParam.y = 1.0 - saturate(fIntensity);
    
    float angle = saturate(abs(dot(NormalWS, eyeDir)));
    oBeamParam.z = pow(angle, cBeamAnglePower);
    
    float fForward = saturate(abs(dot(SpotForwardView, float3(0,0,1))));
    oBeamParam.w = fForward * cBeamForwardPower;
    
    #if defined(D3D11) && defined(CLIPPLANE)
        oClip = dot(oPos, cClipPlane);
    #endif

}

void PS(
    #if defined(D3D11) && defined(CLIPPLANE)
        float iClip : SV_CLIPDISTANCE0,
    #endif
    float4 iWorldPos  : TEXCOORD2,
    float2 iScreenPos : TEXCOORD5,
    float4 iBeamParam : TEXCOORD6,
    
    out float4 oColor : OUTCOLOR0)
{
    float4 diffColor = cMatDiffColor;
    
    float FinalIntensity = lerp(iBeamParam.y * iBeamParam.z, iBeamParam.y * (iBeamParam.z + iBeamParam.w), iBeamParam.x);
    
    float BeamDepth = iWorldPos.w;
    float depth = Sample2DLod0(DepthBuffer, iScreenPos).r;
    #ifdef HWDEPTH
        depth = ReconstructDepth(depth);
    #endif
    
    float diffZ = (depth - BeamDepth) * (cFarClipPS - cNearClipPS);
    float fade = saturate(1.0 - diffZ * cBeamFadeScale);

    FinalIntensity *=cBeamIntensity;
    diffColor.rgb = FinalIntensity * max(diffColor.rgb - fade, float3(0.0, 0.0, 0.0));
    
    oColor = diffColor;
}
