# BLACK GUNS

## Etapa 2 — Sensores do Mobile VR

A Etapa 2 fortalece a camada de sensores do aplicativo Android. O celular continua sendo um dispositivo de tracking: a câmera traseira é reservada para visão computacional futura e sua imagem não é exibida ao jogador.

### O que foi implementado

- Leitura contínua do giroscópio.
- Leitura contínua do acelerômetro.
- Calibração automática do bias do giroscópio durante 2 segundos.
- Botão para recalibrar os sensores.
- Filtro passa-baixa do acelerômetro.
- Correção lenta de pitch/roll usando a direção da gravidade.
- Integração do giroscópio para resposta rápida de orientação.
- Timestamps em microssegundos.
- Sequência de pacotes.
- Envio de tracking limitado a 60 Hz quando o socket estiver aberto.
- Pacote de tracking versão 2 com valores brutos, filtrados e bias do gyro.
- Painel local mostrando estado, gyro, acelerômetro e bias.
- Remoção da integração dupla do acelerômetro para posição: nesta etapa ainda não existe positional tracking visual real, então a posição não é inventada por drift.

### Importante

Esta etapa ainda **não é positional tracking 6DoF real**. O gyro fornece orientação relativa e o acelerômetro ajuda a corrigir pitch/roll pela gravidade. O yaw permanece relativo e pode sofrer drift.

A próxima camada será a fusão com visão da câmera traseira para obter tracking espacial/posicional de verdade. A câmera continua invisível ao usuário.

### Teste

1. Abra o projeto no Godot 4.
2. Rode o app no Android.
3. Toque em **INICIAR SENSORES**.
4. Durante a calibração, deixe o celular completamente parado por aproximadamente 2 segundos.
5. Movimente o celular e observe os valores do gyro/acelerômetro.
6. Use **RECALIBRAR SENSORES** quando necessário.
7. A conexão UDP continua apenas como estrutura de transporte; o receiver do PC ainda não faz parte desta etapa.

### Próximas etapas

**Mobile Etapa 3 — Head tracking visual/6DoF:** câmera + sensores, correção de drift e movimento espacial.

Depois: hand tracking real, mãos 3D, teleporte/interação, display estéreo e, somente então, conexão completa com o jogo no PC.
