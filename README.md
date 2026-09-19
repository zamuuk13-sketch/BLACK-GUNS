# BLACK GUNS

BLACK GUNS é um projeto de VR para PC no qual o celular Android funciona como dispositivo de tracking e, futuramente, como display VR. O jogo e a renderização principal ficam no PC.

## Arquitetura

```
📱 Celular Android
  ├─ gyro + acelerômetro
  ├─ câmera traseira invisível
  ├─ tracking visual
  ├─ MediaPipe Hand Landmarker
  ├─ mãos 3D / interação
  └─ display estéreo L/R
          │
      USB / Wi-Fi
          │
          ▼
🖥️ PC
  ├─ ambiente 3D / jogo
  ├─ servidor BLACK_GUNS_VR
  ├─ recebe tracking
  └─ futuramente renderiza e envia frames VR L/R
```

## Estado atual

### Mobile — Stage 9
Implementado:
- sensores IMU;
- calibração de gyro;
- câmera traseira como sensor invisível;
- estimador visual monocular relativo;
- MediaPipe Hand Landmarker no Android;
- até duas mãos / 21 landmarks;
- esqueletos 3D das mãos;
- pinch, grab, hold, release e throw;
- teleporte com arco;
- display estéreo local L/R;
- IPD e escala de calibração;
- cliente PC integrado;
- descoberta automática do PC por UDP;
- conexão TCP;
- handshake `BLACK_GUNS_VR`;
- envio de tracking para o PC;
- suporte ao túnel USB via ADB reverse.

### PC — Stage 3
Implementado:
- captura estéreo L/R no PC por SubViewport;
- renderização dos dois olhos a partir da câmera 3D do PC;
- JPEG em baixa resolução configurável;
- streaming UDP fragmentado para reduzir o impacto de pacotes grandes;
- 20 FPS e 640×360 por olho como configuração inicial;
- cliente Android recompõe os chunks e decodifica os JPEGs;
- display mobile troca as texturas locais pelos frames recebidos do PC.

**Nota:** esta primeira implementação do Stage 3 usa Wi-Fi/UDP para o vídeo. O caminho USB continua disponível para tracking/TCP e terá transporte de vídeo dedicado posteriormente.

### PC — Stage 2
Implementado:
- ambiente 3D de teste;
- servidor TCP na porta `39100`;
- discovery UDP na porta `39101`;
- protocolo `BLACK_GUNS_VR` versão `1`;
- handshake `hello/hello_ack`;
- resposta a `ping/pong`;
- recebimento do transporte de tracking;
- ferramenta `pc/tools/usb_tunnel.bat`.

## Conexão

### Wi-Fi
1. Abra a cena `pc/scenes/PCConnection.tscn` no PC.
2. Deixe o PC e o celular na mesma rede.
3. No aplicativo, use `AUTO` no campo **PC IP**.
4. O celular procura `BLACK_GUNS_DISCOVER` em UDP `39101`.
5. O PC responde com seu endereço.
6. O celular abre TCP `39100` e executa o handshake.

### USB
1. Ative Depuração USB no Android.
2. Conecte o celular ao PC.
3. Execute `pc/tools/usb_tunnel.bat`.
4. No aplicativo, informe `127.0.0.1`.
5. A conexão usa TCP `39100` através do ADB reverse.

## Hand tracking Android

O backend nativo usa MediaPipe Tasks Vision e é empacotado como plugin Android do Godot. O modelo `hand_landmarker.task` é baixado durante o build do plugin e não precisa ficar versionado no repositório.

Build:
1. JDK 17 + Android SDK configurados.
2. Execute `build_hand_tracking_plugin.bat`.
3. Gere o APK Android pelo Godot.
4. Conceda permissão de câmera.
5. Teste os sensores e o tracking.

## O que ainda não está concluído

Estas partes são intencionalmente posteriores:
- transporte de vídeo otimizado para USB;
- streaming real PC → celular em codec de vídeo dedicado (H.264/H.265/WebRTC) para substituir o protótipo JPEG/UDP;
- compressão/codec de vídeo para baixa latência;
- transporte dedicado de frames VR L/R;
- aplicação final de lens distortion no display;
- calibração visual completa do headset;
- positional tracking 6DoF métrico robusto;
- integração definitiva de tracking no gameplay PC;
- jogo Black Guns final: mapa, armas, inimigos, mãos com mesh final, física e gameplay.

O protótipo de conexão não deve ser confundido com streaming VR: nesta fase o celular envia dados de tracking, mas ainda não recebe a imagem renderizada pelo PC.

## Próximo passo

**PC Stage 4 — integração do tracking no PC:** aplicar rotação/posição recebidas do celular às câmeras VR do PC e sincronizar a pose com o stream L/R. Depois disso, podemos evoluir o transporte para codec de vídeo dedicado e otimizar latência.
