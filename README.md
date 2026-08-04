# oficina-infra-k8s

Infraestrutura Kubernetes (via Terraform) do Tech Challenge Fase 3 (POSTECH). Parte do split de repositórios descrito em [ADR-0005](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0005-split-de-repositorios.md), no repositório principal [`oficina-api`](https://github.com/Williamnasci/oficina-api).

## Propósito

Provisiona, via Terraform, os recursos AWS que dão suporte ao cluster Kubernetes e ao roteamento externo:

- **EC2 `t3.micro`** (Free Tier) hospedando um cluster **Kind** (Kubernetes-in-Docker) com IP público — não Amazon EKS, por decisão de custo registrada e corrigida em [ADR-0003](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0003-cluster-kubernetes-local.md) (a versão inicial da ADR previa Kind só local no notebook; foi corrigida porque o API Gateway precisa de um alvo de integração alcançável pela rede).
- **API Gateway (HTTP API v2)**, com a estratégia de roteamento híbrida (rotas explícitas para auth/health + proxy protegido por Lambda Authorizer para a aplicação) definida em [ADR-0004](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0004-api-gateway-roteamento.md).

O cluster em si (manifests de Deployment, Service, HPA da aplicação) continua no repositório [`oficina-api`](https://github.com/Williamnasci/oficina-api) — este repositório provisiona a infraestrutura onde o cluster roda, não o que roda dentro dele.

## Tecnologias

- Terraform
- AWS (EC2, API Gateway HTTP API v2, IAM)
- Kind (Kubernetes-in-Docker)
- GitHub Actions (CI/CD)

## Status

🚧 Em construção. Estrutura de repositório e branch protection configuradas; migração/adaptação do Terraform hoje existente em `oficina-api/infra/terraform` (que já usa o provider `tehcyx/kind`) para provisionar a EC2 + Kind remotamente é o próximo passo do roteiro.

## Deploy e execução

_A preencher assim que o pipeline de CI/CD e o deploy estiverem funcionais._

## Diagrama

Ver [Diagrama de Componentes](https://github.com/Williamnasci/oficina-api/blob/main/docs/architecture-components.md) no repositório principal.
