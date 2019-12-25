Shader "GUPParticle/Memory"
{
  Properties
  {
    _SelfTex ("Texture", 2D) = "white" { }
  }
  SubShader
  {
    Tags { "RenderType" = "Opaque" }
    
    Pass
    {
      CGPROGRAM
      
      #pragma vertex vert
      #pragma fragment frag
      
      #include "UnityCG.cginc"
      
      struct appdata
      {
        float4 vertex: POSITION;
        float2 uv: TEXCOORD0;
      };
      
      struct v2f
      {
        float2 uv: TEXCOORD0;
        float4 vertex: SV_POSITION;
      };
      
      sampler2D _SelfTex;
      float4 _SelfTex_TexelSize;
      
      float rand(float n);
      float2 rand2D(float2 st);
      float3 rand3D(float3 vec);
      float pNoise(float2 pos);
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
      
      v2f vert(appdata v)
      {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        return o;
      }
      
      
      
      fixed4 frag(v2f i): SV_Target
      {
        //前フレームの座標を取得
        uint2 particleID = uvToParticleID(i.uv, _SelfTex_TexelSize.zw);
        uint localOffset = particleID.y;
        float3 pos = 0;
        //初期化と更新処理
        if (_Time.y < 0.1)
        {
          pos = rand3D(float3(i.uv, 0));
        }
        else
        {
          pos = getPos(particleID.x);
          //xzは適当に揺らす
          //yは降下
          float t = _Time.y * rand(particleID);
          pos.x += (pNoise(float2(particleID.x, t))-0.5)*0.003;
          pos.z += (pNoise(float2(t, particleID.x))-0.5)*0.003;
          pos.y -= (rand3D(particleID.xxx) + 1) * 0.001 + 0.001;
          if(pos.y < - 1) pos = rand3D(float3(i.uv, _Time.y));
        }
        
        //ピクセルのよって出力する成分が違うので分岐
        fixed4 col = 1;
        if (particleID.y == 0)col = pack(pos.x);
        else if(particleID.y == 1)col = pack(pos.y);
        else if(particleID.y == 2)col = pack(pos.z);
        
        return col;
      }
      
      //ランダム系
      float rand(float n)
      {
        return frac(sin(n) * 63452.5453123);
      }
      float2 rand2D(float2 st)
      {
        st = float2(dot(st, float2(127.1, 311.7)),
        dot(st, float2(269.5, 183.3)));
        return - 1.0 + 2.0 * frac(sin(st) * 43758.5453123);
      }
      float3 rand3D(float3 vec)
      {
        
        float rand1 = dot(vec, float3(127.1, 311.7, 264.7));
        float rand2 = dot(vec, float3(269.5, 183.3, 336.2));
        float rand3 = dot(vec, float3(301.7, 231.1, 142.6));
        
        float3 rand = float3(rand1, rand2, rand3);
        return - 1.0 + 2.0 * frac(sin(rand) * 43758.5453123);
      }
      //ノイズ
      float pNoise(float2 pos)
      {
        float2 i_o = floor(pos);
        float2 f = frac(pos);
        
        float2 sm = smoothstep(0, 1, f);
        
        float dot_o = 0;
        float dot_x = 0;
        float dot_y = 0;
        float dot_xy = 0;
        {
          float2 i_x = i_o + float2(1, 0);
          float2 i_y = i_o + float2(0, 1);
          float2 i_xy = i_o + float2(1, 1);
          float2 rand_o = rand2D(i_o);
          float2 rand_x = rand2D(i_x);
          float2 rand_y = rand2D(i_y);
          float2 rand_xy = rand2D(i_xy);
          
          float2 toPos_o = pos - i_o;
          float2 toPos_x = pos - i_x;
          float2 toPos_y = pos - i_y;
          float2 toPos_xy = pos - i_xy;
          
          dot_o = dot(rand_o, toPos_o) * 0.5 + 0.5;
          dot_x = dot(rand_x, toPos_x) * 0.5 + 0.5;
          dot_y = dot(rand_y, toPos_y) * 0.5 + 0.5;
          dot_xy = dot(rand_xy, toPos_xy) * 0.5 + 0.5;
        }
        
        float value1 = lerp(dot_o, dot_x, sm.x);
        float value2 = lerp(dot_y, dot_xy, sm.x);
        float value3 = lerp(0, value2 - value1, sm.y);
        return value1 + value3;
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
        uint particleID = rawID / 3;
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
      
      float3 getPos(uint particleID)
      {
        uint rawID = particleID * 3;
        float x = unpackFloat(tex2D(_SelfTex, idToUV(rawID, _SelfTex_TexelSize)));
        float y = unpackFloat(tex2D(_SelfTex, idToUV(rawID + 1, _SelfTex_TexelSize)));
        float z = unpackFloat(tex2D(_SelfTex, idToUV(rawID + 2, _SelfTex_TexelSize)));
        return float3(x, y, z);
      }
      ENDCG
      
    }
  }
}
