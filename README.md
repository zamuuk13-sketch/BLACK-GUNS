# BLACK GUNS

## Mobile VR — Etapa 3: câmera + base de head tracking

A Etapa 3 adiciona a câmera traseira como **sensor invisível** do aplicativo. A imagem da câmera não é colocada em nenhum controle visual, viewport ou tela do usuário.

### O que foi implementado

- Declaração da permissão Android da câmera.
- Descoberta do feed de câmera pelo CameraServer.
- Preferência pelo feed traseiro quando o Android informa a posição.
- Ativação do feed da câmera em modo sensor.
- Leitura periódica da textura/frame size sem renderizar a imagem.
- Contagem e timestamp das amostras da câmera.
- Diagnóstico local do estado da câmera.
- Pacotes de tracking versão 3 com metadados do sensor visual.
- IMU da Etapa 2 continua integrada: gyro calibrado + acelerômetro filtrado + correção de pitch/roll.
- Arquitetura preparada para um estimador visual que futuramente fará a fusão câmera + IMU.

### O que ainda NÃO foi fingido

Esta etapa **não declara positional tracking 6DoF real**. Ter acesso aos frames da câmera não cria automaticamente uma estimativa de posição.

O estimador visual/visual-inercial ainda precisa analisar os frames, encontrar características estáveis, acompanhar essas características entre frames e fundir esse movimento com o IMU. Isso será implementado como a próxima evolução do head/positional tracking.

Também não há imagem da câmera na interface.

### Teste no Android

1. Compile e instale o APK.
2. Conceda a permissão de câmera.
3. Inicie os sensores.
4. Observe o painel **CÂMERA**.
5. O estado esperado é **ATIVA / SENSOR INVISÍVEL** e o contador de amostras deve aumentar.
6. Movimente o aparelho e confirme que gyro/acelerômetro continuam atualizando.
7. Nenhuma imagem da câmera deve aparecer na tela.

### Próxima etapa

**Mobile Etapa 4 — estimador visual/inercial de head tracking e positional tracking:** processamento dos frames da câmera + IMU, rastreamento de movimento, referência espacial, correção de drift e posição relativa 6DoF.

Depois entram hand tracking real, mãos 3D, teleporte/interação e display estéreo.

A conexão completa com o jogo no PC continua para depois da construção do sistema VR mobile.
