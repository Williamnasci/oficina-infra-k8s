# oficina-infra-k8s

Infraestrutura Kubernetes (via Terraform) do Tech Challenge Fase 3 (POSTECH). Parte do split de repositórios descrito em [ADR-0005](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0005-split-de-repositorios.md), no repositório principal [`oficina-api`](https://github.com/Williamnasci/oficina-api).

## Propósito

Provisiona, via Terraform, os recursos AWS que dão suporte ao cluster Kubernetes e ao roteamento externo:

- **EC2 `t3.small`** hospedando um cluster **Kind** (Kubernetes-in-Docker) com IP público — não Amazon EKS, por decisão de custo registrada em [ADR-0003](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0003-cluster-kubernetes-local.md). O ADR documenta duas correções: primeiro, Kind precisou sair do notebook (API Gateway precisa de um alvo de rede alcançável); depois, `t3.micro` (Free Tier) se mostrou insuficiente na prática sob carga real, daí `t3.small` (fora do Free Tier, custo baixo).
- **API Gateway (HTTP API v2)**, com a estratégia de roteamento híbrida (rotas explícitas para auth/health + proxy protegido por Lambda Authorizer para a aplicação) definida em [ADR-0004](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0004-api-gateway-roteamento.md).

O cluster em si (manifests de Deployment, Service, HPA da aplicação) continua no repositório [`oficina-api`](https://github.com/Williamnasci/oficina-api) — este repositório provisiona a infraestrutura onde o cluster roda, não o que roda dentro dele.

## Tecnologias

- Terraform
- AWS (EC2, API Gateway HTTP API v2, IAM)
- Kind (Kubernetes-in-Docker)
- GitHub Actions (CI/CD)

## Status

✅ Aplicado contra a conta AWS real: EC2 `t3.small` (Ubuntu 24.04) rodando Kind, kubeconfig externo publicado no Secrets Manager (`oficina/k8s/kubeconfig`), `kubectl` externo validado com sucesso (node `Ready`, TLS válido), aplicação principal implantada e respondendo via NodePort. Acesso operacional via **SSM Session Manager** (sem SSH/chave).

A instância original (`t3.micro`, Free Tier) ficou não-responsiva sob carga real (control-plane do Kind + réplicas da aplicação), mesmo após reboot — ver a correção registrada em [ADR-0003](https://github.com/Williamnasci/oficina-api/blob/main/docs/adr/0003-cluster-kubernetes-local.md). `t3.small` resolveu. API Gateway ainda não implementado (depende da Lambda de auth — ver roteiro no `oficina-api`).

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
