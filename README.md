# BLACK GUNS

## Mobile VR — Etapa 4: estimador visual + IMU

A Etapa 4 evolui a câmera traseira invisível para um **estimador visual leve**, mantendo o IMU da etapa anterior. A imagem da câmera continua sendo apenas uma fonte interna de dados e não é colocada em nenhum controle visual, viewport ou tela do usuário.

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
- Conversão dos frames para uma imagem pequena em tons de cinza para reduzir custo no celular.\n- Rastreamento de pequenos patches por block matching em uma grade de pontos.\n- Mediana dos vetores para rejeitar parte do ruído/outliers.\n- Confiança baseada na quantidade de pontos e no erro médio do matching.\n- Integração limitada do movimento visual em uma posição **relativa** para teste local.\n- Proteção contra passos excessivos para evitar explosões de posição.\n- Estado visual separado do IMU para futura fusão visual-inercial.

### O que ainda NÃO foi fingido

Esta etapa **não declara positional tracking 6DoF real**. Ter acesso aos frames da câmera não cria automaticamente uma estimativa de posição.

O estimador visual/visual-inercial ainda precisa analisar os frames, encontrar características estáveis, acompanhar essas características entre frames e fundir esse movimento com o IMU. Isso será implementado como a próxima evolução do head/positional tracking.

Também não há imagem da câmera na interface.

### Teste no Android

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

**Próxima evolução — VIO/6DoF:** fusão mais forte entre features visuais, gyro e acelerômetro, estabilização da referência espacial, rejeição de outliers, estimativa de profundidade/escala e correção de drift.

Depois entram hand tracking real, mãos 3D, teleporte/interação e display estéreo.

A conexão completa com o jogo no PC continua para depois da construção do sistema VR mobile.
