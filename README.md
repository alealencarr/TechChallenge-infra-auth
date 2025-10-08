# TechChallenge Infra API Gateway
[Documentação completa do projeto](https://alealencarr.github.io/TechChallenge/)

Cria o API Management e configura-o para apontar para os serviços app-api e app-function.

### Descrição
Este repositório é a "tampa da panela" da nossa arquitetura. Ele é responsável por criar e configurar o Azure API Management (APIM), que atua como o único ponto de entrada (Gateway) para toda a nossa aplicação.

Ele centraliza a segurança, o roteamento e a aplicação de políticas, como o limite de requisições (rate limiting).

### Tecnologias Utilizadas
Terraform: Ferramenta de Infraestrutura como Código (IaC).

Azure API Management (APIM): O serviço de Gateway da Azure.

XML: Para a definição das políticas de roteamento dentro do APIM.

### Responsabilidades
Criar o serviço de API Management.

Definir os backends, que são os "endereços" dos nossos serviços internos (a API no AKS e a Azure Function).

Definir a API (lanchonete-api) e as suas operações ("pega-tudo") que o Gateway irá aceitar.

Implementar a política de roteamento inteligente que:

Encaminha pedidos de autenticação (/api/auth, /api/register) para a Azure Function.

Encaminha todos os outros pedidos para a API principal no AKS.

Aplicar políticas de segurança, como o rate limiting.

### Dependências
Todos os outros repositórios: Este é o último repositório a ser executado. Ele depende que todos os outros serviços (VNet, AKS, Function App) estejam no ar e com os seus endpoints (internos ou externos) definidos.

### Processo de CI/CD
O pipeline de CI/CD (.github/workflows/deploy-infra.yml) automatiza a gestão da infraestrutura:

Em Pull Requests: Executa terraform plan.

Em Merges na main: Executa terraform apply.
