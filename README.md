# BLACK GUNS

## Mobile VR — Etapa 5: hand tracking real

A Etapa 5 adiciona **hand tracking real on-device** usando MediaPipe Hand Landmarker no Android. A câmera traseira continua sendo somente um sensor invisível: o frame é convertido internamente para RGB e enviado ao backend nativo para inferência. Nenhum frame da câmera é exibido.

### O que foi implementado

- Declaração da permissão Android da câmera.
- Descoberta do feed de câmera pelo CameraServer.
- Preferência pelo feed traseiro quando o Android informa a posição.
- Ativação do feed da câmera em modo sensor.
- Leitura periódica da textura/frame size sem renderizar a imagem.
- Contagem e timestamp das amostras da câmera.
- Diagnóstico local do estado da câmera.
- Pacotes de tracking versão 4 com movimento visual relativo, confiança, pontos rastreados e timestamps.
- IMU da Etapa 2 continua integrada: gyro calibrado + acelerômetro filtrado + correção de pitch/roll.
- Conversão dos frames para uma imagem pequena em tons de cinza para reduzir custo no celular.\n- Rastreamento de pequenos patches por block matching em uma grade de pontos.\n- Mediana dos vetores para rejeitar parte do ruído/outliers.\n- Confiança baseada na quantidade de pontos e no erro médio do matching.\n- Integração limitada do movimento visual em uma posição **relativa** para teste local.\n- Proteção contra passos excessivos para evitar explosões de posição.\n- Estado visual separado do IMU para futura fusão visual-inercial.\n- Backend Android nativo em Kotlin usando MediaPipe Tasks Vision.\n- Detecção de até duas mãos.\n- 21 landmarks por mão, incluindo x/y normalizados e z relativo.\n- Classificação esquerda/direita e confiança.\n- Processamento em modo VIDEO para aproveitar tracking temporal do MediaPipe.\n- Interface Godot `BlackGunsHandTracking` para receber os resultados.\n- Dados de mãos incluídos no pacote de tracking versão 5.

### Arquitetura do hand tracking\n\nO backend usa um plugin Android v2, porque o MediaPipe Tasks Vision é uma biblioteca Android nativa. O plugin é compilado em AAR e empacotado no projeto Godot. O modelo oficial `hand_landmarker.task` é baixado automaticamente durante o build do plugin e colocado nos assets do AAR. O MediaPipe fornece 21 landmarks por mão e também landmarks de mundo; nesta etapa enviamos ao Godot os 21 pontos de imagem (x/y/z) para manter o transporte leve. citeturn5search0turn1search0\n\n### O que ainda NÃO foi fingido

Esta etapa **não declara positional tracking 6DoF real**. Ter acesso aos frames da câmera não cria automaticamente uma estimativa de posição.

O estimador visual/visual-inercial ainda precisa analisar os frames, encontrar características estáveis, acompanhar essas características entre frames e fundir esse movimento com o IMU. Isso será implementado como a próxima evolução do head/positional tracking.

Também não há imagem da câmera na interface. O tracking é local/on-device; não depende de API paga ou servidor de inferência.

### Build do backend Android\n\nO plugin usa o sistema de Android plugins v2 do Godot, que exige build Gradle. citeturn2search1turn4search5\n\nA partir da raiz do repositório:\n\n1. Tenha JDK 17 e Android SDK configurados.\n2. Entre em `android/black_guns_hand_tracking`.\n3. Execute `gradle :plugin:assemble`.\n4. O build baixa o modelo `hand_landmarker.task`, compila o AAR e copia o plugin para `addons/BlackGunsHandTracking`.\n5. No Godot, use Gradle Build para Android e ative o plugin quando ele aparecer nas configurações de plugins.\n\n### Teste no Android

1. Compile e instale o APK.
2. Conceda a permissão de câmera.
3. Inicie os sensores.
4. Observe **CÂMERA** e **VISUAL**.
5. O estado esperado é **ATIVA / SENSOR INVISÍVEL** e o contador de amostras deve aumentar.
6. Movimente lentamente o aparelho diante de uma cena com textura e observe `FLOW dx/dy`, pontos e confiança.
7. A posição visual deve variar de forma relativa, sem saltos grandes.
8. Confirme que gyro/acelerômetro continuam atualizando.
9. Nenhuma imagem da câmera deve aparecer na tela.

### Próxima etapa

**Próxima etapa — Mobile Etapa 6: mãos 3D:** converter os 21 landmarks detectados em esqueletos 3D estáveis, com orientação, escala, suavização e preparação para colisão/interação.

Depois entram hand tracking real, mãos 3D, teleporte/interação e display estéreo.

A conexão completa com o jogo no PC continua para depois da construção do sistema VR mobile.
