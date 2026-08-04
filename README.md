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

✅ Aplicado contra a conta AWS real em 2026-08-03: EC2 `t3.micro` (Ubuntu 24.04) rodando Kind, kubeconfig externo publicado no Secrets Manager (`oficina/k8s/kubeconfig`), `kubectl` externo validado com sucesso (node `Ready`, TLS válido). Acesso operacional via **SSM Session Manager** (sem SSH/chave).

⚠️ **Instabilidade conhecida:** a instância ficou não-responsiva (timeout de handshake TLS, comandos SSM presos) após várias recriações consecutivas nesta sessão — provável esgotamento de créditos de CPU e/ou memória insuficiente (1GB) para um cluster Kind completo em `t3.micro`. Se isso persistir, a correção é subir para `t3.small` (sai do Free Tier, custo pequeno). API Gateway fica para depois que a Lambda de auth existir (ver roteiro no `oficina-api`).

## Deploy e execução

### Pré-requisitos (uma vez só)

1. Bucket S3 de backend remoto (compartilhado com `oficina-infra-database`) — ver instruções no `oficina-api` (`docs/phase-3-plan.md`).
2. Secrets do repositório GitHub:
   - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — credenciais IAM (não root) com permissão para EC2, IAM (role/instance profile) e Secrets Manager.
   - `OFICINA_API_REPO_TOKEN` (opcional) — Personal Access Token com escopo `repo` sobre `Williamnasci/oficina-api`, usado pela pipeline para publicar automaticamente o `KUBE_CONFIG` gerado como secret naquele repositório. Sem isso, copie manualmente (comando abaixo).

### Local

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply

# depois do apply (leva alguns minutos até o user_data terminar):
aws secretsmanager get-secret-value --secret-id oficina/k8s/kubeconfig --query SecretString --output text > kubeconfig
gh secret set KUBE_CONFIG --repo Williamnasci/oficina-api < kubeconfig
```

### CI/CD

`.github/workflows/terraform.yml`: `terraform plan` em todo PR; `terraform apply` automático ao mergear em `main`, seguido de push automático do `KUBE_CONFIG` para o `oficina-api` (se `OFICINA_API_REPO_TOKEN` estiver configurado).

### Acesso operacional (debug)

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```

## Diagrama

Ver [Diagrama de Componentes](https://github.com/Williamnasci/oficina-api/blob/main/docs/architecture-components.md) no repositório principal.
