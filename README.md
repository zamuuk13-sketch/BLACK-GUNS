# BLACK GUNS

## Etapa 1 — Base do Mobile VR

Esta etapa cria a fundação do aplicativo Android que será o companheiro VR/tracking do Black Guns.

### O que foi concluído

- Projeto Godot 4 com cena principal 3D.
- Ambiente de teste com piso, iluminação, obstáculos e câmera.
- Interface inicial do Mobile VR.
- Campo para IP do PC e porta UDP.
- Abertura/fechamento do socket UDP.
- Pacote de handshake manual para validar o transporte.
- Estrutura versionada dos pacotes de tracking.
- Leitura inicial de giroscópio e acelerômetro.
- Pedido de permissão da câmera no Android.
- A câmera do celular continua sendo reservada para tracking; a imagem da câmera não é exibida.
- Esqueleto de 21 pontos por mão preparado para receber um provider real.
- Base visual da curva azul de teleporte.

### Como testar a Etapa 1

1. Abra o projeto no Godot 4.
2. Execute a cena principal.
3. No celular, informe o IP do PC e a porta 42424.
4. Toque em ABRIR CONEXÃO UDP.
5. Toque em INICIAR SENSORES.
6. Use ENVIAR PACOTE DE TESTE para verificar que o aplicativo consegue enviar um datagrama.

> Importante: abrir um socket UDP não significa que o PC já respondeu. O receiver do PC será implementado em uma etapa própria.

### Protocolo inicial

Cada pacote possui type, version, sequence e timestamp_ms.

O handshake usa black_guns_handshake.

O tracking usa black_guns_tracking.

O campo hand_tracking já possui left e right, mas os landmarks reais ainda não foram implementados.

### Próxima etapa

**Etapa 2 — Sensores:** calibrar e estruturar gyro/acelerômetro, orientação da cabeça, timestamps, filtros e envio consistente dos dados.

Depois entram tracking visual 6DoF, hand tracking real, conexão PC↔celular completa e streaming estéreo L/R.
