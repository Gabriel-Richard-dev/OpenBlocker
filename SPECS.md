# OpenBlock — Mobile App Specification

**Version:** 1.0.0  
**Status:** Proposed  
**Product:** Open-source mobile application  
**Primary platform:** Android  
**Future platform:** iOS, subject to platform API limitations  
**License:** MIT  
**Architecture principle:** Local-first, privacy-first, no mandatory backend.

## 1. Visão do produto

O OpenBlock é um aplicativo mobile que ajuda as pessoas a interromper o consumo automático de conteúdo e recuperar o controle sobre o tempo gasto em redes sociais.

O aplicativo deve permitir que o usuário bloqueie ou limite feeds infinitos, vídeos curtos e outros mecanismos de distração, preservando, sempre que tecnicamente possível, as funcionalidades úteis dos aplicativos originais.

**Tagline:** Take back your attention.

### Problema

Aplicativos como Instagram, TikTok, YouTube e Facebook oferecem feeds que podem incentivar sessões de uso prolongadas. Bloquear o aplicativo inteiro nem sempre é uma boa solução, pois o usuário também pode precisar dele para estudar, trabalhar ou se comunicar.

### Proposta de valor

O OpenBlock oferece:

- Bloqueio seletivo de distrações quando suportado pelo sistema.
- Limites de tempo por aplicativo ou categoria.
- Sessões de foco.
- Regras personalizadas.
- Estatísticas armazenadas localmente.
- Ausência de conta obrigatória, publicidade e rastreamento por padrão.

O objetivo não é controlar o usuário, mas ajudá-lo a cumprir as próprias intenções.

## 2. Plataformas e estratégia

### Android — plataforma inicial

O Android será a primeira plataforma, pois oferece recursos de acessibilidade e APIs de uso de aplicativos que podem viabilizar funcionalidades de controle mais específicas.

A implementação deverá investigar e combinar:

- `AccessibilityService` para identificar elementos visíveis e determinados eventos de interface.
- `UsageStatsManager` para consultar informações de uso, mediante autorização.
- `SYSTEM_ALERT_WINDOW`, se necessário, para apresentar uma camada de bloqueio e mediante autorização explícita.
- `WorkManager` para tarefas agendadas que não exijam execução em tempo real.
- `DataStore` para configurações locais.

A estratégia exata deverá ser validada com protótipos. Não se deve assumir que um serviço de acessibilidade consegue cancelar de maneira confiável todo gesto de rolagem dentro de outros aplicativos.

### iOS — expansão futura

O iOS possui restrições diferentes. As APIs `FamilyControls`, `ManagedSettings` e `DeviceActivity` permitem implementar determinados mecanismos de controle de aplicativos e categorias, sujeitos às autorizações e aos requisitos de distribuição da Apple.

O MVP para iOS deverá priorizar limites e bloqueios de aplicativos ou categorias. O bloqueio seletivo de elementos internos de outros aplicativos, como apenas os Reels do Instagram, não deve ser prometido.

## 3. Funcionalidades

### P0 — MVP

#### F01. Dashboard

Tela inicial com:

- Estado atual do OpenBlock.
- Sessão de foco ativa, se houver.
- Aplicativos e regras configurados.
- Tempo de uso disponível, quando os dados estiverem autorizados.
- Atalhos para iniciar foco e editar regras.

Os números apresentados devem distinguir dados efetivamente medidos de estimativas.

#### F02. Configuração de bloqueios

O usuário pode criar regras para aplicativos instalados e selecionar o comportamento desejado.

Tipos de regra:

- Bloquear um aplicativo durante determinado período.
- Limitar o tempo de uso diário.
- Bloquear ou ocultar um feed específico quando houver suporte.
- Exibir uma tela de pausa antes de continuar.
- Desativar uma regra temporariamente.

Cada regra deve indicar quais permissões são necessárias e o que efetivamente consegue controlar.

#### F03. Modo de foco

O usuário escolhe uma duração, por exemplo, 25, 45 ou 60 minutos.

Durante a sessão:

- As regras selecionadas ficam ativas.
- O aplicativo mostra o tempo restante.
- O usuário pode acompanhar o estado da sessão.
- Ao terminar, o bloqueio temporário é encerrado conforme as regras configuradas.

O MVP deve evitar depender de um processo permanentemente ativo em segundo plano quando isso puder ser substituído por APIs mais apropriadas.

#### F04. Bloqueio de scroll no Android

Esta é a funcionalidade central do produto.

O sistema deve investigar duas estratégias complementares:

**Estratégia A — bloqueio seletivo**

Utilizar um serviço de acessibilidade para identificar, em aplicativos suportados, elementos associados a feeds ou vídeos curtos. Quando uma regra for acionada, apresentar uma intervenção que impeça ou interrompa o acesso à seção configurada, dentro das possibilidades técnicas do Android.

**Estratégia B — bloqueio de sessão**

Quando o bloqueio seletivo não for confiável, apresentar uma tela de pausa ou bloqueio para o aplicativo ou sessão configurada, respeitando as permissões e as limitações do sistema.

O comportamento deve ser específico por aplicativo. Não utilizar seletores, coordenadas de tela ou heurísticas genéricas como se funcionassem em todos os dispositivos.

#### F05. Presets

Presets iniciais:

- **Study Mode:** regras para reduzir distrações durante o estudo.
- **No Shorts:** bloqueio de vídeos curtos nos aplicativos compatíveis.
- **Social Media Limit:** limites para redes sociais.
- **Deep Focus:** sessão de foco com regras selecionadas.
- **Custom:** configuração manual.

Cada preset deve informar quais plataformas são realmente suportadas.

#### F06. Regras e exceções

O usuário pode:

- Ativar e desativar regras individualmente.
- Configurar horários.
- Definir limites de uso.
- Criar exceções.
- Editar ou remover regras.
- Consultar as permissões necessárias.

Uma regra específica pode substituir uma regra geral, de acordo com uma precedência documentada.

#### F07. Privacidade

O aplicativo não exige cadastro, servidor ou conta externa.

As configurações e estatísticas ficam armazenadas localmente. Nenhum histórico de uso deve ser enviado a servidores próprios por padrão.

#### F08. Onboarding e permissões

O primeiro acesso deve explicar, em linguagem simples:

1. O que o OpenBlock consegue fazer.
2. Quais permissões são necessárias.
3. Por que cada permissão é solicitada.
4. Quais dados podem ser observados.
5. Como desativar o serviço ou revogar permissões.

O usuário deve autorizar cada recurso sensível no próprio sistema operacional. O aplicativo não pode ativar essas permissões silenciosamente.

### P1 — evolução

- Estatísticas diárias e semanais.
- Histórico de sessões de foco.
- Calendário de horários de bloqueio.
- Tela de pausa personalizável.
- Modo estrito opcional.
- Exportação e importação de configurações.
- Presets compartilháveis.
- Suporte a mais aplicativos.
- Widget de início rápido.

### P2 — longo prazo

- Versão iOS.
- Sincronização opcional entre dispositivos.
- Regras comunitárias verificadas.
- Integração com calendários.
- Relatórios de produtividade.
- Personalização avançada das intervenções.

Esses recursos não devem atrasar a validação do mecanismo central de bloqueio.

## 4. Experiência do usuário

### 4.1. Navegação principal

A aplicação deve ter quatro áreas principais:

**Home**
- Estado do bloqueio.
- Sessão de foco.
- Resumo do dia.
- Ações rápidas.

**Rules**
- Lista de regras.
- Aplicativos selecionados.
- Presets.
- Exceções.

**Statistics**
- Tempo de uso, quando disponível.
- Sessões concluídas.
- Regras acionadas.
- Evolução por período.

**Settings**
- Permissões.
- Aparência.
- Privacidade.
- Exportação de dados.
- Sobre e licença.

### 4.2. Identidade visual

A interface deve ser minimalista, moderna e discreta.

Diretrizes:

- Tema claro e escuro.
- Tipografia legível.
- Cores neutras com uma cor de destaque.
- Componentes acessíveis.
- Navegação simples com uma mão.
- Animações rápidas e não intrusivas.
- Estados vazios que orientem o usuário.
- Sem rankings, punições ou mensagens de culpa.

### 4.3. Tela de pausa

Quando uma regra for acionada, o OpenBlock poderá apresentar uma tela como:

> Você abriu este feed durante sua sessão de foco.
>
> Quer voltar ao que estava fazendo?

A tela pode oferecer ações como retornar, adiar por um período configurado ou encerrar a sessão, conforme as regras definidas pelo usuário.

O aplicativo deve evitar dificultar artificialmente o acesso às configurações ou impedir a recuperação do controle pelo proprietário do dispositivo.

## 5. Arquitetura técnica

### Stack recomendada

| Camada | Tecnologia |
|---|---|
| Aplicativo multiplataforma | Flutter |
| Linguagem de interface | Dart |
| Integração Android | Kotlin |
| Serviço de acessibilidade | Android AccessibilityService |
| Informações de uso | UsageStatsManager |
| Persistência de configurações | DataStore |
| Banco local de estatísticas | SQLite, se necessário |
| Gerenciamento de estado | Riverpod |
| Testes unitários | flutter_test |
| Testes de integração | Flutter integration_test |
| Automação | GitHub Actions |
| Documentação | Markdown |

Flutter será responsável pela interface compartilhada. Os mecanismos específicos de controle do sistema operacional serão implementados em módulos nativos.

### Estrutura sugerida

```text
openblock/
├── app/
│   ├── lib/
│   │   ├── features/
│   │   │   ├── home/
│   │   │   ├── rules/
│   │   │   ├── focus/
│   │   │   ├── statistics/
│   │   │   └── settings/
│   │   ├── core/
│   │   ├── data/
│   │   └── main.dart
│   └── test/
├── android/
│   └── app/src/main/kotlin/
│       └── .../openblock/
│           ├── accessibility/
│           ├── usage/
│           ├── overlay/
│           └── storage/
├── docs/
│   ├── architecture.md
│   ├── privacy.md
│   ├── supported-apps.md
│   ├── permissions.md
│   └── contributing.md
├── .github/workflows/
├── LICENSE
├── README.md
└── CONTRIBUTING.md
```

A separação entre `app` e os módulos nativos deve ser mantida apenas se a configuração do repositório justificar essa organização. O importante é isolar o código de plataforma da lógica de produto.

## 6. Modelo de dados

### BlockRule

```dart
enum BlockMode {
  appLimit,
  scheduledBlock,
  selectiveFeed,
  pauseScreen,
}

class BlockRule {
  final String id;
  final String name;
  final String packageName;
  final BlockMode mode;
  final bool enabled;
  final int? dailyLimitMinutes;
  final List<int> activeWeekdays;
  final String? startTime;
  final String? endTime;
}
```

O modelo deverá evoluir conforme os modos de bloqueio forem implementados. Regras de feed seletivo precisam de configurações específicas por aplicativo, em vez de depender apenas do nome do pacote.

### FocusSession

```dart
class FocusSession {
  final String id;
  final DateTime startedAt;
  final DateTime plannedEndAt;
  final List<String> activeRuleIds;
  final bool completed;
}
```

Os registros devem usar datas e durações consistentes, incluindo tratamento de mudanças de fuso horário e reinicialização do dispositivo.

## 7. Segurança e privacidade

Requisitos obrigatórios:

- Nenhum login obrigatório.
- Nenhuma telemetria por padrão.
- Nenhum histórico enviado para serviços externos.
- Armazenamento local.
- Solicitação explícita de permissões.
- Explicação clara sobre o uso da acessibilidade.
- Nenhuma coleta de conteúdo de telas além do estritamente necessário para as funções ativadas.
- Nenhuma execução de código remoto.
- Possibilidade de apagar estatísticas e configurações.
- Documentação de ameaças e limitações.

O serviço de acessibilidade pode ter acesso a informações sensíveis da interface. A implementação deverá processar os dados localmente, minimizar sua retenção e evitar registrar textos de mensagens, senhas ou conteúdo pessoal.

O projeto também deve avaliar as políticas vigentes da Google Play para serviços de acessibilidade, permissões de sobreposição e controle de aplicativos antes da publicação. A disponibilidade técnica de uma API não garante aprovação na loja.

## 8. Critérios de aceitação

O MVP estará pronto quando:

- [ ] O aplicativo Flutter puder ser instalado em um dispositivo Android compatível.
- [ ] O usuário conseguir concluir o onboarding.
- [ ] As permissões forem solicitadas de maneira transparente.
- [ ] As regras persistirem após fechar e reabrir o aplicativo.
- [ ] O usuário conseguir criar, editar e excluir regras.
- [ ] Uma sessão de foco puder ser iniciada e encerrada.
- [ ] O bloqueio funcionar no conjunto de aplicativos oficialmente suportados.
- [ ] O sistema lidar corretamente com permissões revogadas e serviço interrompido.
- [ ] A interface indicar quando o bloqueio não estiver funcionando.
- [ ] Os dados permanecerem locais por padrão.
- [ ] Os fluxos críticos possuírem testes automatizados.
- [ ] A documentação explicar limitações e permissões.

O bloqueio seletivo de feeds deverá ter critérios adicionais por aplicativo, com testes em dispositivos reais. Não será considerado concluído apenas porque uma tela de sobreposição funciona.

## 9. Plano de desenvolvimento

### Fase 1 — protótipo Android

- Criar o projeto Flutter.
- Desenvolver onboarding e dashboard.
- Implementar persistência local.
- Criar um protótipo nativo de acessibilidade.
- Investigar como detectar o aplicativo em primeiro plano.
- Testar a possibilidade de intervir em um feed específico.

**Objetivo:** validar a viabilidade técnica antes de desenvolver toda a interface.

### Fase 2 — regras e permissões

- Criar o motor de regras.
- Implementar configurações por aplicativo.
- Implementar limites e horários.
- Integrar os módulos nativos com Flutter.
- Tratar revogação de permissões.

### Fase 3 — primeira intervenção seletiva

- Selecionar um aplicativo de referência.
- Implementar um adaptador específico.
- Detectar os elementos desejados.
- Implementar a intervenção.
- Validar que outras funcionalidades continuam acessíveis.
- Testar mudanças de interface e diferentes tamanhos de tela.

### Fase 4 — sessões de foco e interface

- Finalizar o dashboard.
- Implementar o temporizador.
- Adicionar presets.
- Criar estatísticas locais.
- Melhorar acessibilidade e experiência de uso.

### Fase 5 — estabilização

- Testar diferentes fabricantes e versões Android.
- Avaliar consumo de bateria.
- Testar encerramento do processo e reinicialização.
- Revisar privacidade e permissões.
- Preparar documentação e distribuição.

## 10. Estratégia de testes

### Testes unitários

- Validação de regras.
- Precedência de exceções.
- Horários e limites.
- Cálculo de duração das sessões.
- Persistência e migrações.
- Estados de permissão.

### Testes de integração

- Flutter ↔ módulos nativos.
- Ativação e desativação do serviço.
- Recuperação após reinicialização.
- Funcionamento com permissões revogadas.
- Atualização de configurações.

### Testes em dispositivos reais

- Aplicativo de referência em primeiro plano.
- Mudança entre aplicativos.
- Navegação em feeds dinâmicos.
- Diferentes resoluções e escalas de tela.
- Consumo de bateria.
- Comportamento após atualização do aplicativo-alvo.

## 11. Open source

Licença recomendada: MIT.

O repositório deverá incluir:

- README com instalação e limitações.
- Política de privacidade.
- Guia de contribuição.
- Código de conduta.
- Política de segurança.
- Lista de dispositivos e aplicativos testados.
- Templates de issues e pull requests.
- Processo de revisão de regras específicas por aplicativo.

Cada integração deverá documentar os recursos testados, as permissões exigidas e as limitações conhecidas.

## 12. Definição do MVP

A primeira versão não precisa suportar todos os aplicativos.

O MVP deve entregar:

1. Um aplicativo Flutter funcional.
2. Configurações e regras locais.
3. Sessões de foco.
4. Limites ou bloqueios por aplicativo.
5. Um protótipo validado de bloqueio seletivo de feed no Android.
6. Um primeiro adaptador de aplicativo documentado.
7. Testes e documentação open source.

A expansão para outras plataformas e aplicativos deve depender dos resultados dos testes de viabilidade.

## 13. Visão de longo prazo

O OpenBlock deve se tornar uma ferramenta open source de autocontrole digital, com suporte progressivo a plataformas e mecanismos de bloqueio.

Seu diferencial não será apenas impedir o uso de aplicativos, mas permitir que cada pessoa configure uma relação mais consciente com eles.

**Princípios permanentes:**

- Open source.
- Privacidade por padrão.
- Funcionamento local.
- Transparência sobre as limitações.
- Controle nas mãos do usuário.

**GitHub description:** An open-source, privacy-first mobile app to help you break infinite scrolling and regain control of your attention.
