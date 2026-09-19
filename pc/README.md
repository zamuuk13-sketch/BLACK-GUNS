# Black Guns — PC Stages 1–2

## Stage 1 — Ambiente 3D
A cena pc/scenes/PCEnvironment.tscn fornece o laboratório 3D inicial.

## Stage 2 — Conexão PC ↔ celular
A cena pc/scenes/PCConnection.tscn adiciona o servidor de comunicação.

### Protocolo
- TCP: 39100
- UDP discovery: 39101
- protocolo: BLACK_GUNS_VR
- versão: 1
- mensagens: JSON delimitado por newline

O PC aceita hello, ping, tracking e disconnect.
O PC responde hello_ack e pong.

### Wi-Fi
O celular poderá descobrir o PC por UDP na mesma rede e depois abrir TCP em 39100.

### USB
pc/tools/usb_tunnel.bat usa adb reverse para criar:
celular 127.0.0.1:39100 -> USB -> PC 127.0.0.1:39100

### Limite desta etapa
O transporte e handshake do lado PC estão preparados. O cliente Android/Godot será integrado antes do teste real PC ↔ celular. O streaming de vídeo fica para a etapa seguinte.
