# Documentacao Completa - Rota Otimizada Flutter

## 1. Visao Geral

O projeto `rota_otimizada_flutter` e a versao Flutter do app mobile de roteirizacao.

Objetivo principal:
- receber uma lista de enderecos;
- opcionalmente extrair enderecos por camera (OCR no backend);
- enviar para o backend otimizar a ordem de paradas;
- apresentar resumo da rota;
- abrir o trajeto no Google Maps e copiar link.

Escopo atual:
- plataformas alvo: Android e iOS;
- backend preservado: `https://rota.inteligenciacomercial.net.br`;
- paridade funcional com o app React Native anterior.

## 2. Estrutura do Projeto

Diretorios principais:
- `lib/config`: configuracoes globais (ex.: base URL e timeout).
- `lib/domain`: modelos, regras puras e tipagem de falhas.
- `lib/services`: integracoes externas (HTTP e Google Maps link builder).
- `lib/state`: estado global com `ChangeNotifier`.
- `lib/screens`: telas/rotas da aplicacao.
- `lib/widgets`: componentes reutilizaveis de UI.
- `lib/theme`: tokens visuais e `ThemeData`.
- `test`: testes unitarios de regras puras.

## 3. Fluxo Funcional do App

1. Tela `AddressInputScreen`:
- usuario digita/cola enderecos (um por linha);
- usuario pode preencher endereco inicial opcional;
- usuario pode capturar imagem com camera;
- app envia imagem para `/api/scan` e mescla enderecos encontrados;
- ao avancar, app garante ao menos 2 enderecos validos.

2. Tela `ConfirmScreen`:
- lista os enderecos finais;
- primeiro endereco e tratado como ponto de partida;
- usuario pode remover enderecos (exceto o primeiro);
- app chama `/api/optimize`;
- em sucesso, navega para `ResultScreen`.

3. Tela `ResultScreen`:
- exibe resumo: tempo, distancia, numero de paradas;
- mostra lista ordenada de paradas;
- gera link do Google Maps;
- permite abrir o Maps ou copiar o link.

## 4. Navegacao

Rotas declaradas em `lib/app_routes.dart`:
- `/` (`AppRoutes.addressInput`)
- `/confirm` (`AppRoutes.confirm`)
- `/result` (`AppRoutes.result`)

Navegacao configurada em [main.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/main.dart).

## 5. Estado Global

Estado central em [app_state.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/state/app_state.dart):
- `addresses`: lista normalizada de enderecos;
- `optimizedRoute`: resultado da otimizacao.

Operacoes principais:
- `setAddresses(...)`: normaliza e salva enderecos;
- `clearRoute()`: limpa resultado atual;
- `scanImage(imagePath)`: chama API scan, mescla enderecos unicos e atualiza estado;
- `optimizeRoute(addresses)`: valida quantidade minima e chama API optimize.

Padrao de gerenciamento:
- `ChangeNotifier` com `Provider`;
- tela observa via `context.watch<AppState>()`;
- comandos via `context.read<AppState>()`.

## 6. Camada de Dominio

Arquivos:
- [address_rules.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/domain/address_rules.dart)
- [optimized_route.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/domain/optimized_route.dart)
- [stop.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/domain/stop.dart)
- [app_failure.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/domain/app_failure.dart)

Regras relevantes:
- `parseLines`: quebra texto multiline, aplica trim e remove linhas vazias.
- `buildRouteAddresses`: define endereco inicial final e remove duplicacao desse endereco nas paradas.
- `mergeUnique`: uniao sem duplicatas mantendo ordem da primeira ocorrencia.
- `AppFailure`: erro tipado para separar erro tecnico de mensagem de usuario.

Tipos de falha (`AppFailureKind`):
- `validation`, `network`, `timeout`, `invalidResponse`, `server`, `addressNotFound`, `unknown`.

## 7. Integracao com Backend

Servico principal: [api_service.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/services/api_service.dart)

Configuracoes:
- base URL: `AppConfig.apiBaseUrl` (com override por `--dart-define=API_BASE_URL=...`);
- timeout: `AppConfig.apiTimeout` (10s).

Endpoints usados:
1. `POST /api/scan`
- request: multipart/form-data
- campo de arquivo: `image`
- response esperada: `{ "addresses": ["..."] }`

2. `POST /api/optimize`
- request JSON: `{ "addresses": ["..."] }`
- response esperada:
  - `stops: [{ address: string }]`
  - `totalTime: string`
  - `totalDistance: string`
  - `numberOfStops: number`

Tratamento de erro:
- erros HTTP nao-2xx viram `AppFailure`;
- mensagem do backend e extraida de `message` ou `error` quando possivel;
- caso conhecido de endereco nao encontrado mapeia para `addressNotFound`.

## 8. Integracao com Google Maps

Builder: [maps_link_builder.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/services/maps_link_builder.dart)

Regras:
- sem paradas: retorna `https://www.google.com/maps`;
- com paradas:
  - `origin` = primeira parada;
  - `destination` = ultima parada;
  - `waypoints` = paradas intermediarias separadas por `|`.

Consumo na UI:
- `url_launcher` abre app externo;
- `Clipboard` copia URL para area de transferencia.

## 9. UI e Tema

Tema em [app_theme.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/lib/theme/app_theme.dart):
- cores padrao (`AppColors`);
- espacamentos (`AppSpacing`);
- raios (`AppRadii`);
- sombras (`AppShadows`);
- `AppTheme.light()` aplicado no `MaterialApp`.

Componentes de base em `lib/widgets`:
- `AppLayout`: estrutura com cabecalho e rodape fixo;
- `AppButton`: botao primario/secundario;
- `AppCard`, `appInputDecoration`, `showAppAlert`;
- `LoadingOverlay`;
- `AddressTile`, `RouteSummaryCard`, `RouteStopTile`.

## 10. Setup e Execucao

Pre-requisito:
- Flutter SDK instalado e no `PATH`.

Se o projeto ainda nao tiver pastas nativas (`android`/`ios`), executar:

```powershell
flutter create . --platforms=android,ios --project-name rotaotimizada --org com.thebieelgt
```

Dependencias, analise e testes:

```powershell
flutter pub get
flutter analyze
flutter test
```

Rodar app:

```powershell
flutter run
```

## 11. Permissoes Nativas

Camera:
- iOS: adicionar `NSCameraUsageDescription` em `ios/Runner/Info.plist`;
- Android: validar manifest gerado pelo plugin `image_picker`.

## 12. Testes Existentes

Arquivos em `test`:
- [address_rules_test.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/test/address_rules_test.dart)
- [maps_link_builder_test.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/test/maps_link_builder_test.dart)
- [optimized_route_test.dart](C:/Users/Admin/Documents/Projects/RotaOptimizer-front-back/RoteOptimizer-ReactNative/rota_otimizada_flutter/test/optimized_route_test.dart)

Cobertura atual:
- normalizacao e composicao de enderecos;
- geracao de URL do Maps;
- parsing/validacao basica do contrato de rota otimizada.

## 13. Decisoes de Arquitetura

Decisoes aplicadas:
- separar regras puras (`domain`) de efeitos externos (`services`) e de UI (`screens/widgets`);
- adotar erro tipado (`AppFailure`) para desacoplar mensagem de usuario da mensagem tecnica;
- centralizar tokens visuais no tema;
- manter `Provider + ChangeNotifier` por simplicidade e baixo overhead para o escopo atual.

Tradeoff atual:
- `ChangeNotifier` e simples e suficiente no escopo, mas para fluxos mais complexos pode evoluir para abordagem mais robusta (ex.: `Riverpod`, `Bloc`, ou similar).

## 14. Guia de Manutencao Rapida

Para adicionar uma nova regra de negocio:
1. implemente em `lib/domain`;
2. cubra com teste unitario em `test`;
3. consuma via `AppState` ou `Service`.

Para adicionar nova integracao externa:
1. crie servico em `lib/services`;
2. mapeie excecoes para `AppFailure`;
3. use mensagens amigaveis via `userMessage`.

Para alterar estilo global:
1. atualize `lib/theme/app_theme.dart`;
2. mantenha telas consumindo `AppColors/AppRadii/AppSpacing`.
