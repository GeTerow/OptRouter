# Documentação do App Flutter — Rota Otimizada

> Aplicativo mobile (Flutter) que recebe uma lista de endereços e retorna a rota otimizada, com integração ao Google Maps.

---

## Índice

1. [Visão Geral da Arquitetura](#1-visão-geral-da-arquitetura)
2. [Arquivos Raiz do `lib/`](#2-arquivos-raiz-do-lib)
   - [`main.dart`](#maindart)
   - [`app_routes.dart`](#app_routesdart)
3. [Pasta `config/`](#3-pasta-config)
   - [`app_config.dart`](#app_configdart)
4. [Pasta `domain/`](#4-pasta-domain)
   - [`stop.dart`](#stopdart)
   - [`optimized_route.dart`](#optimized_routedart)
   - [`app_failure.dart`](#app_failuredart)
   - [`address_rules.dart`](#address_rulesdart)
5. [Pasta `services/`](#5-pasta-services)
   - [`api_service.dart`](#api_servicedart)
   - [`maps_link_builder.dart`](#maps_link_builderdart)
6. [Pasta `state/`](#6-pasta-state)
   - [`app_state.dart`](#app_statedart)
7. [Pasta `theme/`](#7-pasta-theme)
   - [`app_theme.dart`](#app_themedart)
8. [Pasta `screens/`](#8-pasta-screens)
   - [`address_input_screen.dart`](#address_input_screendart)
   - [`confirm_screen.dart`](#confirm_screendart)
   - [`result_screen.dart`](#result_screendart)
9. [Pasta `widgets/`](#9-pasta-widgets)
   - [`app_layout.dart`](#app_layoutdart)
   - [`app_button.dart`](#app_buttondart)
   - [`app_card.dart`](#app_carddart)
   - [`app_form_field.dart`](#app_form_fielddart)
   - [`app_text.dart`](#app_textdart)
   - [`app_alerts.dart`](#app_alertsdart)
   - [`address_tile.dart`](#address_tiledart)
   - [`route_stop_tile.dart`](#route_stop_tiledart)
   - [`route_summary_card.dart`](#route_summary_carddart)
   - [`loading_overlay.dart`](#loading_overlaydart)
10. [Fluxo de Dados — Do começo ao fim](#10-fluxo-de-dados--do-começo-ao-fim)
11. [Dependências Externas (`pubspec.yaml`)](#11-dependências-externas-pubspecyaml)

---

## 1. Visão Geral da Arquitetura

O app segue uma arquitetura em camadas bem definida, separando responsabilidades de forma clara:

```
lib/
├── main.dart              ← Ponto de entrada: inicializa o app e o provider
├── app_routes.dart        ← Constantes das rotas de navegação
│
├── config/                ← Configurações do ambiente (URL da API, timeouts)
├── domain/                ← Modelos de dados e regras de negócio puras (sem Flutter)
├── services/              ← Comunicação externa (HTTP, construção de links)
├── state/                 ← Gerenciamento de estado global (Provider)
├── theme/                 ← Design system: cores, espaçamentos, sombras, tema
├── screens/               ← Telas completas do app
└── widgets/               ← Componentes reutilizáveis de UI
```

**Padrão de gerenciamento de estado:** O app usa o pacote `provider`. O `AppState` estende `ChangeNotifier` e é disponibilizado globalmente via `ChangeNotifierProvider` no `main.dart`. As telas consomem o estado via `context.read<AppState>()` (ação pontual) e `context.watch<AppState>()` (reativo, reconstrói ao mudar).

---

## 2. Arquivos Raiz do `lib/`

### `main.dart`

**Papel:** Ponto de entrada absoluto do aplicativo. É o primeiro arquivo executado.

```dart
void main() {
  runApp(const RotaOtimizadaApp());
}
```

- Define a classe `RotaOtimizadaApp`, que é um `StatelessWidget` (widget sem estado local).
- Envolve tudo com `ChangeNotifierProvider`, tornando o `AppState` acessível em qualquer lugar da árvore de widgets.
- Configura o `MaterialApp` com:
  - `title`: Nome do app.
  - `theme`: Usa `AppTheme.light()` da pasta `theme/`.
  - `debugShowCheckedModeBanner: false`: Remove o banner vermelho de "debug".
  - `initialRoute`: A rota inicial é `AppRoutes.addressInput` (tela de entrada de endereços).
  - `routes`: Mapeia as strings de rota para os widgets de tela correspondentes.

**Por que isso importa:** Qualquer tela ou widget filho pode chamar `context.read<AppState>()` para acessar ou modificar o estado global porque o `ChangeNotifierProvider` está aqui, na raiz da árvore.

---

### `app_routes.dart`

**Papel:** Centraliza os nomes das rotas de navegação como constantes `static const`.

```dart
class AppRoutes {
  static const addressInput = '/';
  static const confirm = '/confirm';
  static const result = '/result';
}
```

**Por que isso importa:** Evitar strings "mágicas" espalhadas pelo código. Se o nome de uma rota mudar, só precisa mudar aqui. As telas navegam assim:

```dart
Navigator.of(context).pushNamed(AppRoutes.confirm);
```

---

## 3. Pasta `config/`

### `app_config.dart`

**Papel:** Centraliza toda a configuração do ambiente de execução. Funciona como o arquivo `.env` do app.

**O que ele resolve:**

1. **URL da API por plataforma:** O endereço `localhost` funciona diferente em cada ambiente:
   - No navegador web: `http://localhost:3008`
   - No emulador Android: `http://10.0.2.2:3008` (o emulador usa esse IP para referenciar o `localhost` da máquina host)
   - Em outras plataformas (iOS, desktop): `http://localhost:3008`

2. **Injeção via variável de ambiente:** Se a app for compilada com `--dart-define=API_BASE_URL=https://meu-servidor.com`, esse valor tem prioridade sobre o autodetectado.

3. **Helper `apiUri(path)`:** Monta a URL completa de forma segura, garantindo que não haja barras duplas:
   ```dart
   AppConfig.apiUri('/api/optimize') // → http://10.0.2.2:3008/api/optimize
   ```

4. **Timeouts:**
   - `apiTimeout`: 10 segundos para chamadas normais (ex: otimizar rota).
   - `scanTimeout`: 30 segundos para envio de imagens (operação mais pesada).

5. **Modo Offline Preview:** A flag `OFFLINE_PREVIEW=true` pode ser passada em tempo de compilação para que o app gere rotas fictícias sem precisar de um servidor rodando.

---

## 4. Pasta `domain/`

> Esta pasta contém a "inteligência" do negócio. **Nenhum arquivo aqui importa pacotes do Flutter.** São classes Dart puras, o que as torna facilmente testáveis.

### `stop.dart`

**Papel:** Modelo de dados mais simples — representa uma única parada na rota.

```dart
class Stop {
  final String address;
  // fromJson, ==, hashCode
}
```

- `fromJson`: Constrói um `Stop` a partir de um `Map<String, dynamic>` vindo do JSON da API.
- Implementa `==` e `hashCode` para que duas paradas com o mesmo endereço sejam consideradas iguais (importante para comparações no `OptimizedRoute`).

---

### `optimized_route.dart`

**Papel:** Modelo de dados que representa o resultado completo de uma otimização.

Campos:
| Campo | Tipo | Descrição |
|---|---|---|
| `stops` | `List<Stop>` | Lista ordenada de paradas |
| `totalTime` | `String` | Ex: `"45 min"` |
| `totalDistance` | `String` | Ex: `"12.3 km"` |
| `numberOfStops` | `int` | Total de paradas |
| `mapsUrl` | `String` | URL do Google Maps (pode ser vazia) |

- `fromJson`: Faz a deserialização defensiva do JSON. Valida que `stops` é uma lista antes de processar, e filtra paradas com endereço vazio.
- Implementa `==` comparando elemento a elemento da lista de `stops` (não usa o `listEquals` padrão, fazendo um loop manual para mais controle).

---

### `app_failure.dart`

**Papel:** Sistema de erros tipado. Substitui lançar `Exception` genérica por uma classe com contexto rico.

O enum `AppFailureKind` categoriza os erros:

| Tipo | Causa |
|---|---|
| `validation` | Dados inválidos fornecidos pelo usuário (ex: menos de 2 endereços) |
| `network` | Sem conexão à internet |
| `timeout` | Servidor demorou mais que o limite |
| `invalidResponse` | Servidor retornou JSON malformado |
| `server` | Erro HTTP 4xx/5xx |
| `addressNotFound` | API do Google Maps não encontrou o endereço |
| `unknown` | Qualquer outra exceção inesperada |

A propriedade `userMessage` retorna uma mensagem amigável em português para o usuário final, separada da `technicalMessage` (que é o erro técnico bruto, útil para debug).

**Por que isso importa:** As telas capturam `AppFailure` no `catch` e exibem `error.userMessage` diretamente. Não há lógica de tratamento de erro espalhada nas telas.

---

### `address_rules.dart`

**Papel:** Regras de negócio puras relacionadas à manipulação de endereços. É uma classe utilitária (só métodos estáticos).

Métodos principais:

- **`parseLines(value)`:** Divide um texto por quebra de linha, remove espaços extras e filtra linhas vazias. É usado para ler o `TextEditingController` da tela de entrada.

- **`buildRouteAddresses({addressesText, startAddress})`:** Lógica central para montar a lista final de endereços que será enviada à API:
  1. Faz o parse do texto de endereços.
  2. Remove duplicatas com o endereço de partida.
  3. Se houver um endereço de partida explícito, coloca-o na posição 0.
  4. Se não houver, usa o primeiro da lista como partida.
  5. Retorna `[]` se não houver endereços suficientes.

- **`mergeUnique(current, incoming)`:** Combina dois iteráveis de endereços sem duplicatas (case-insensitive). Usado ao importar endereços via foto da câmera para não duplicar o que já estava digitado.

- **`normalize(addresses)`:** Remove espaços e filtra vazios de uma coleção de endereços.

---

## 5. Pasta `services/`

> Responsável pela comunicação com o mundo externo. Só as classes de serviço fazem chamadas HTTP.

### `api_service.dart`

**Papel:** Toda a lógica de comunicação HTTP com o backend Node.js.

**Arquitetura interna:**

O cliente HTTP (`http.Client`) é injetado via construtor. Isso é fundamental para **testes unitários**: nos testes, um cliente mock é injetado em vez do cliente real, sem precisar de um servidor rodando.

```dart
ApiService({http.Client? client}) : _client = client ?? http.Client();
```

**Endpoints:**

1. **`POST /api/optimize`** — via `optimizeRoute(List<String> addresses)`:
   - Envia os endereços como JSON.
   - Recebe e desserializa um `OptimizedRoute`.

2. **`POST /api/scan`** — via `scanAddressImage(imagePath)` e `scanAddressImageBytes(bytes)`:
   - Envia uma imagem como `multipart/form-data`.
   - Recebe uma lista de strings (endereços extraídos por OCR/IA).
   - Há dois métodos: um que recebe um caminho de arquivo (para Android nativo) e outro que recebe bytes (`Uint8List`) (para Web, onde não há acesso ao sistema de arquivos).

**Método `_safeCall<T>`:** Wrapper genérico que envolve qualquer operação de rede e converte exceções técnicas (`TimeoutException`, `http.ClientException`, `FormatException`) em `AppFailure` tipados. Isso garante que nenhuma exceção técnica vaze para as telas.

**Método `_throwIfFailed(response)`:** Verifica o código HTTP e lança `AppFailure` se não for 2xx. Tenta extrair a mensagem de erro do corpo JSON da resposta do backend.

**Método `_inferMediaType(path)`:** Detecta o tipo MIME correto pelo extensão do arquivo (`.png`, `.heic`, `.webp`, etc.) para envio correto no multipart.

---

### `maps_link_builder.dart`

**Papel:** Constrói a URL de direções do Google Maps a partir de um `OptimizedRoute`.

Lógica:
1. Se a rota já veio com uma `mapsUrl` do backend, usa ela diretamente.
2. Caso contrário, constrói a URL manualmente:
   - `origin`: primeiro endereço.
   - `destination`: último endereço.
   - `waypoints`: todos os endereços do meio, separados por `|`.

```dart
// Exemplo de URL gerada:
// https://www.google.com/maps/dir/?api=1&origin=...&destination=...&waypoints=...|...
```

---

## 6. Pasta `state/`

### `app_state.dart`

**Papel:** O "coração" do app. É o único lugar que mantém e modifica o estado global. Estende `ChangeNotifier` (padrão do pacote `provider`).

**Estado armazenado:**
```dart
List<String> _addresses      // Lista de endereços atual
OptimizedRoute? _optimizedRoute  // Resultado da última otimização (null = sem resultado)
```

**Métodos públicos:**

| Método | O que faz |
|---|---|
| `setAddresses(addresses)` | Normaliza e salva a lista de endereços, notifica listeners |
| `clearRoute()` | Limpa a rota otimizada (ao voltar para editar) |
| `optimizeRoute(addresses)` | Valida, chama a API, salva o resultado. Tem modo offline. |
| `scanImage(imagePath)` | Chama a API de scan por caminho de arquivo, faz merge com endereços existentes |
| `scanImageBytes(bytes, filename)` | Mesma coisa, mas por bytes (para Web) |

**Modo Offline Preview (`_buildPreviewRoute`):**
Quando `AppConfig.offlinePreview == true` (flag de compilação), ou quando ocorre um erro de rede/timeout, o app gera uma rota simulada localmente:
- Tempo estimado: `12 minutos × (n-1 paradas)`
- Distância estimada: `4.5 km × (n-1 paradas)`

Isso permite demonstrar o app sem backend rodando.

**Quando o modo preview é ativado em erro (`_canUsePreviewRoute`):**
- Ativa se: erro de rede, timeout, ou erro desconhecido.
- **Não** ativa se: erro de validação, resposta inválida, erro de servidor, ou endereço não encontrado (esses são erros "legítimos" que o usuário precisa ver).

**`dispose()`:** Fecha o `http.Client` quando o provider é destruído, evitando vazamento de recursos.

---

## 7. Pasta `theme/`

### `app_theme.dart`

**Papel:** Define o Design System do app. Todas as cores, raios de borda, espaçamentos e sombras são definidos aqui como constantes estáticas.

**Por que constantes e não `Theme.of(context)`?**
O design do app é simples e consistente. Usar constantes em vez de resolver pelo contexto é mais performático (sem lookup na árvore) e mais explícito.

**Classes definidas:**

#### `AppColors`
| Constante | Hex | Uso |
|---|---|---|
| `primary` | `#2563EB` | Cor principal (azul), botões, destaques |
| `background` | `#F3F4F6` | Fundo das telas |
| `surface` | branco | Fundo de cards |
| `textStrong` | `#111827` | Títulos e textos mais importantes |
| `text` | `#1F2937` | Texto padrão |
| `textMuted` | `#6B7280` | Labels e rótulos secundários |
| `textSubtle` | `#9CA3AF` | Dicas e textos menos relevantes |
| `border` | `#E5E7EB` | Bordas de separação |
| `overlay` | `#111827` | Fundo do painel de loading |
| `overlayText` | `#F9FAFB` | Texto sobre o painel escuro |

#### `AppRadii`
Raios de borda para diferentes componentes (botões: `12px`, cards: `12px`, overlay: `16px`).

#### `AppSpacing`
Espaçamentos padrão de tela (padding horizontal: `20px`, padding do footer: `12px`).

#### `AppShadows`
Dois níveis de sombra:
- `card`: Sombra sutil para cards normais.
- `overlay`: Sombra mais pronunciada para o modal de loading.

#### `AppTheme`
Método `light()` que cria o `ThemeData` para o `MaterialApp`, usando Material 3 com a cor primária e fonte `Roboto`.

---

## 8. Pasta `screens/`

> As telas são a camada de apresentação. Elas orquestram widgets e consomem o `AppState`, mas não contêm lógica de negócio.

### Fluxo de navegação:

```
AddressInputScreen (/)  →  ConfirmScreen (/confirm)  →  ResultScreen (/result)
        ↑                          |
        └──────────────────────────┘ (pop / volta)
```

---

### `address_input_screen.dart`

**O que é:** Tela inicial. Permite ao usuário digitar endereços manualmente ou escanear com a câmera.

**É `StatefulWidget` porque:** Precisa de estado local para:
- `_loading`: Controlar se o overlay de carregamento está visível.
- `_addressesController` e `_startController`: `TextEditingController`s que gerenciam os campos de texto.
- `_initializedFromStore`: Flag para carregar os endereços do `AppState` apenas uma vez.

**Funcionalidades:**
1. **Campo de endereços** (`TextArea`): Campo multilinha onde o usuário cola ou digita endereços, um por linha. Um contador `"N linha(s)"` é atualizado em tempo real.
2. **Campo de partida** (opcional): Se preenchido, define o primeiro endereço da rota.
3. **Botão "Escanear com a câmera"**: Abre a câmera via `image_picker`, envia os bytes da imagem para o backend, e os endereços extraídos são adicionados à lista. Exibe o `LoadingOverlay` durante a operação.
4. **Botão "Avançar"**: Só habilita quando `_canProceed` é `true` (≥2 endereços válidos). Navega para `ConfirmScreen`.

**Detalhe técnico (`_updatingControllers`):**
Quando o código atualiza os `TextEditingController` programaticamente (ex: após o scan), os listeners dos controllers seriam chamados, causando um `setState` desnecessário. A flag `_updatingControllers` previne isso.

---

### `confirm_screen.dart`

**O que é:** Tela de revisão. Lista os endereços que serão otimizados. O usuário pode remover endereços antes de confirmar.

**É `StatefulWidget` porque:** Mantém `_addressList` (cópia local da lista do `AppState` que pode ser editada) e `_loading`.

**Funcionalidades:**
1. **Lista de endereços:** Renderizada via `ListView.separated` com `AddressTile` para cada item.
2. **Remoção de endereços:** O primeiro item (ponto de partida) **não pode** ser removido. Os demais têm um botão de lixeira.
3. **Botão "Otimizar Rota":** Chama `AppState.optimizeRoute()`, exibe o `LoadingOverlay`, e em caso de sucesso navega para `ResultScreen`. Em caso de erro, exibe um diálogo.
4. **Guard de segurança:** No `didChangeDependencies`, se a tela for acessada com menos de 2 endereços (estado inválido), redireciona imediatamente para a tela inicial.

---

### `result_screen.dart`

**O que é:** Tela final com a rota otimizada. Mostra resumo e lista de paradas, e permite abrir no Google Maps.

**É `StatefulWidget` porque:** Mantém `_copied` — estado visual temporário do botão "Copiar Link" que muda para "Copiado!" por 1.8 segundos.

**Usa `context.watch<AppState>()`** (reativo): Se a rota no estado global for apagada (ex: o usuário navega de volta e modifica endereços), a tela é reconstruída e detecta `route == null`, redirecionando para a tela inicial.

**Funcionalidades:**
1. **`RouteSummaryCard`:** Exibe tempo total, distância total e número de paradas.
2. **Lista de paradas:** `RouteStopTile` para cada parada da rota otimizada.
3. **Botão "Abrir no Maps":** Usa `url_launcher` para abrir o link do Google Maps no aplicativo externo.
4. **Botão "Copiar Link":** Copia a URL do Maps para o clipboard com feedback visual temporário.

---

## 9. Pasta `widgets/`

> Componentes reutilizáveis. Nenhum deles acessa o `AppState` diretamente — recebem tudo via parâmetros.

### `app_layout.dart`

**Papel:** Template de tela. Toda tela do app usa `AppLayout` como widget raiz.

Estrutura que ele monta:
```
Scaffold
└── SafeArea
    └── Column
        ├── _AppHeader (título + botão voltar opcional)  → altura fixa 64px
        ├── Expanded(child: child)                        → conteúdo scrollável da tela
        └── SafeArea (bottom)
            └── Container (footer com borda superior)    → ações (botões)
```

O `footer` é opcional. Se não passado, não renderiza a barra inferior. O `onBack` é opcional — se passado, exibe o ícone de seta para voltar no header.

---

### `app_button.dart`

**Papel:** Botão padronizado com suporte a variantes.

Variantes via enum `AppButtonVariant`:
- **`primary`** (padrão): Fundo azul (`AppColors.primary`), texto branco.
- **`secondary`**: Fundo cinza claro (`AppColors.secondaryButton`), texto escuro.

Funcionalidades:
- `icon`: Ícone opcional à esquerda do texto.
- `onPressed: null`: Desabilita o botão automaticamente (muda a cor para `disabledButton`).
- Largura total (`double.infinity`), altura fixa de 52px, borda arredondada.

---

### `app_card.dart`

**Papel:** Container card com visual padronizado (fundo branco, borda arredondada, sombra).

Exporta também `AppCardTitle` e `AppHelperText`, usados dentro dos cards para títulos e textos de ajuda.

---

### `app_form_field.dart`

**Papel:** Exporta a função `appInputDecoration(hintText)`, que retorna um `InputDecoration` padronizado para todos os campos `TextField` do app. Garante consistência visual nos campos de entrada.

---

### `app_text.dart`

**Papel:** Componentes de texto reutilizáveis com estilos predefinidos (ex: `AppCardTitle`, `AppHelperText`).

---

### `app_alerts.dart`

**Papel:** Função `showAppAlert(context, {title, message})` que exibe um `AlertDialog` padronizado.

Uso típico nas telas:
```dart
await showAppAlert(context, title: 'Erro', message: error.userMessage);
```

---

### `address_tile.dart`

**Papel:** Card de endereço individual, usado na `ConfirmScreen`.

Variações visuais:
- **Ponto de partida (`isStart: true`):** Tem uma barra vertical azul na lateral esquerda, ícone de bandeira, e o texto `"Ponto de Partida"` em azul abaixo do endereço.
- **Paradas normais:** Ícone de menu, sem barra lateral.
- **Botão de deletar:** Só aparece se `onDelete` não for null (ou seja, não aparece no ponto de partida).

---

### `route_stop_tile.dart`

**Papel:** Card de parada na `ResultScreen`. Mostra o número sequencial da parada e o endereço.

Diferente do `AddressTile` (usado para edição), este é somente de visualização.

---

### `route_summary_card.dart`

**Papel:** Card de resumo na `ResultScreen`. Exibe as três métricas da rota (tempo, distância, número de paradas) em linhas separadas por divisores.

Composto internamente por `_SummaryRow`, um widget privado (prefixo `_`) que renderiza cada linha `Label: Valor`.

---

### `loading_overlay.dart`

**Papel:** Overlay de carregamento animado que cobre toda a tela enquanto uma operação assíncrona está em progresso.

**Implementação técnica:**
- `Positioned.fill`: Cobre toda a tela (colocado dentro de um `Stack` na tela).
- `BackdropFilter` com `ImageFilter.blur`: Borra o conteúdo atrás do overlay com `sigmaX/Y = 8`.
- Container semi-transparente escuro centralizado com o spinner e texto.

**Animação customizada (`_CometRingPainter`):**
- Dois anéis concêntricos que giram em direções opostas.
- Cada anel usa um `SweepGradient` que vai de transparente para a cor sólida, criando um efeito de "cometa com cauda".
- Um ponto central pulsa usando `sin(progress * 2π)` para efeito orgânico.
- Controlado por `AnimationController` com `repeat()` — roda indefinidamente até ser descartado.

---

## 10. Fluxo de Dados — Do começo ao fim

```
Usuário digita endereços
        │
        ▼
AddressInputScreen
  ├── _addressesController (TextEditingController)
  ├── _startController (TextEditingController)
  └── [Botão Avançar]
        │
        ▼ AddressRules.buildRouteAddresses()
        │ (monta lista final com ponto de partida correto)
        │
        ▼ AppState.setAddresses(addresses)
        │ (salva no estado global, notifica listeners)
        │
        ▼ Navigator.pushNamed(AppRoutes.confirm)
        │
        ▼
ConfirmScreen
  ├── Lê AppState.addresses
  ├── [Usuário pode remover paradas]
  └── [Botão Otimizar]
        │
        ▼ AppState.optimizeRoute(addresses)
        │   ├── ApiService.optimizeRoute(addresses)
        │   │       └── POST /api/optimize
        │   │               └── OptimizedRoute.fromJson(response)
        │   └── Salva _optimizedRoute, notifica listeners
        │
        ▼ Navigator.pushNamed(AppRoutes.result)
        │
        ▼
ResultScreen
  ├── context.watch<AppState>().optimizedRoute
  ├── RouteSummaryCard (tempo, distância, paradas)
  ├── Lista de RouteStopTile
  └── [Botão Abrir no Maps]
        │
        ▼ MapsLinkBuilder.googleDirectionsUrl(route)
        │ url_launcher.launchUrl(uri)
        │
        ▼ Google Maps (app externo)
```

---

## 11. Dependências Externas (`pubspec.yaml`)

| Pacote | Versão | Para que serve |
|---|---|---|
| `http` | `^1.2.2` | Chamadas HTTP ao backend |
| `http_parser` | `^4.0.2` | Utilitário para `MediaType` (tipo MIME no multipart) |
| `image_picker` | `^1.1.2` | Acesso à câmera e galeria de fotos |
| `provider` | `^6.1.2` | Gerenciamento de estado (`ChangeNotifier`) |
| `url_launcher` | `^6.3.1` | Abrir URLs externas (Google Maps) |

**SDK Flutter requerido:** `>=3.5.0 <4.0.0`

---

*Documentação gerada em: 2026-05-15*
