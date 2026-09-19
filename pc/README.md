# Black Guns — PC Stages 1–2

## Stage 1 — Ambiente 3D
A cena `pc/scenes/PCEnvironment.tscn` fornece o laboratório 3D inicial.

## Stage 2 — Conexão PC ↔ celular

O PC funciona como servidor e o aplicativo Godot Android agora possui o cliente correspondente.

### Protocolo
- TCP: `39100`
- UDP discovery: `39101`
- protocolo: `BLACK_GUNS_VR`
- versão do protocolo: `1`
- mensagens TCP: JSON delimitado por newline
- tracking: enviado pelo celular via TCP a 60 Hz quando os sensores estão ativos

### Fluxo Wi-Fi
1. O aplicativo usa UDP broadcast em `255.255.255.255:39101`.
2. O PC responde `BLACK_GUNS_HERE|BLACK_GUNS_VR|1|39100`.
3. O celular pega o IP de origem da resposta.
4. O cliente abre TCP em `IP_DO_PC:39100`.
5. O cliente envia `hello`.
6. O PC responde `hello_ack`.
7. Depois do handshake, os pacotes de tracking podem ser enviados.

No aplicativo, deixe o campo **PC IP** como `AUTO` para descoberta automática. Também é possível informar o IP manualmente.

### Fluxo USB
`pc/tools/usb_tunnel.bat` usa ADB reverse:

`celular 127.0.0.1:39100 → USB → PC 127.0.0.1:39100`

Nesse modo, informe `127.0.0.1` no campo **PC IP** do aplicativo.

### Cliente mobile
O cliente está em:
`scripts/pc_client.gd`

Ele implementa:
- descoberta UDP;
- conexão TCP;
- handshake `BLACK_GUNS_VR`;
- leitura das respostas do PC;
- envio de tracking;
- desconexão/reconexão;
- status para a interface do aplicativo.

### O que foi corrigido/verificado
- Porta do aplicativo alinhada com a porta real do servidor: `39100`.
- O antigo socket UDP de tracking do mobile foi substituído pelo cliente TCP correspondente ao servidor PC.
- Permissão Android de Internet adicionada.
- Campo padrão passou de um IP fixo para `AUTO`.
- O envio de tracking agora usa o mesmo protocolo do servidor.
- As mãos 3D agora recebem atualização no loop principal.
- A configuração duplicada de `application/config/name` foi corrigida.
- Textos quebrados no `Main.tscn` foram corrigidos.

### Limitação atual
Ainda não há streaming de vídeo. A conexão nesta etapa transporta controle, handshake e tracking. A próxima etapa é **PC Stage 3 — streaming VR**, começando pelo transporte das imagens dos olhos esquerdo/direito do PC para o celular.
