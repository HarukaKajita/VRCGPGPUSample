Shader "GUPParticle/Particle"
{
  Properties
  {
    _MemoryTex ("Texture", 2D) = "white" { }
  }
  SubShader
  {
    Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
    Cull Off
    Blend One One
    ZWrite Off
    Pass
    {
      CGPROGRAM
      
      #pragma vertex vert
      #pragma geometry geom
      #pragma fragment frag
      
      #include "UnityCG.cginc"
      
      struct appdata
      {
        float4 vertex: POSITION;
        float2 uv: TEXCOORD0;
      };
      
      struct v2g
      {
        float2 uv: TEXCOORD0;
        float4 vertex: SV_POSITION;
      };
      
      struct g2f
      {
        float2 uv: TEXCOORD0;
        float4 vertex: SV_POSITION;
      };
      
      sampler2D _MemoryTex;
      float4 _MemoryTex_TexelSize;
      inline uint2 uvToCoord(float2 uv, uint2 textureSize);
      inline uint coordToID(uint2 coord, uint2 textureSize);
      inline uint uvToID(float2 uv, uint2 textureSize);
      inline uint2 idToCellCoord(uint id, uint textureWidth);
      inline float2 coordToUV(uint2 coord, float2 texelSize);
      inline float2 idToUV(uint id, float3 texelSize);
      inline uint2 uvToParticleID(float2 uv, uint2 textureSize);
      fixed4 pack(float value);
      float unpackFloat(fixed4 col);
      float3 getPos(uint particleID);
      
      v2g vert(appdata v)
      {
        v2g o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        return o;
      }
      #define MemorySize 120
      [maxvertexcount(4)]
      void geom(triangle v2g input[3], uint pid: SV_PRIMITIVEID, inout TriangleStream < g2f > outStream)
      {
        if(pid>=MemorySize*MemorySize/3)return;//メモリの数を超えるパーティクルは生成しない
        //pidをパーティクルのidとして扱う。
        float3 pos = getPos(pid);//この中でメモリから座標をサンプリングしてる
        float3 originViewPos = UnityObjectToViewPos(pos);
        [unroll]
        for (uint i = 0; i < 4; i ++)
        {
          float x = i % 2 == 0 ? - 0.5: 0.5;
          float y = i / 2 == 0 ? - 0.5: 0.5;
          float3 viewPos = originViewPos + float3(x, y, 0) * 0.01;
          g2f output;
          output.vertex = mul(UNITY_MATRIX_P, float4(viewPos, 1));
          output.uv = float2(x, y);
          outStream.Append(output);
        }
      }
      
      fixed4 frag(g2f i): SV_Target
      {
				if(length(i.uv)>0.5) discard;
        fixed4 col = 1;tex2D(_MemoryTex, i.uv);
        return col;
      }
      
      //UV to ID系
      inline uint2 uvToCoord(float2 uv, uint2 textureSize)
      {
        return uv * textureSize;
      }
      inline uint coordToID(uint2 coord, uint2 textureSize)
      {
        return coord.y * textureSize.x + coord.x;
      }
      inline uint uvToID(float2 uv, uint2 textureSize)
      {
        uint2 coord = uvToCoord(uv, textureSize.xy);
        return coordToID(coord, textureSize);
      }

      //ID to UV系
      inline uint2 idToCellCoord(uint id, uint textureWidth)
      {
        uint x = id % textureWidth;
        uint y = id / textureWidth;
        return uint2(x, y);
      }
      
      inline float2 coordToUV(uint2 coord, float2 texelSize)
      {
        return coord * texelSize.xy + texelSize.xy / 2.0;
      }
      
      inline float2 idToUV(uint id, float3 texelSize)
      {
        return coordToUV(idToCellCoord(id, texelSize.z), texelSize);
      }
      
      //3pixelでパーティクルの座標を表現するので3pixelおきのIDに変換
      inline uint2 uvToParticleID(float2 uv, uint2 textureSize)
      {
        uint rawID = uvToID(uv, textureSize);
        uint particleID = rawID / 3.0;
        uint localOffset = rawID % 3;
        return uint2(particleID, localOffset);
      }
      
      //float を　fixed4 で表現
      fixed4 pack(float value)
      {
        uint uintVal = asuint(value);
        uint4 elements = uint4(uintVal >> 0, uintVal >> 8, uintVal >> 16, uintVal >> 24);
        fixed4 color = ((elements & 0x000000FF) + 0.5) / 255.0;
        return color;
      }
      
      //fixed4 を　floatにデコード
      float unpackFloat(fixed4 col)
      {
        uint R = uint(col.r * 255) << 0;
        uint G = uint(col.g * 255) << 8;
        uint B = uint(col.b * 255) << 16;
        uint A = uint(col.a * 255) << 24;
        return asfloat(R | G | B | A);
      }

      float3 getPos(uint particleID){
        uint rawID = particleID * 3;
        float x = unpackFloat(tex2Dlod(_MemoryTex, float4(idToUV(rawID, _MemoryTex_TexelSize),0,0)));
        float y = unpackFloat(tex2Dlod(_MemoryTex, float4(idToUV(rawID+1, _MemoryTex_TexelSize),0,0)));
        float z = unpackFloat(tex2Dlod(_MemoryTex, float4(idToUV(rawID+2, _MemoryTex_TexelSize),0,0)));
        return float3(x,y,z);
      }
      ENDCG
      
    }
  }
}
